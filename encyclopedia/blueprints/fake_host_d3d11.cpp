// fake_host_d3d11.cpp — offline WARP harness for reversed-Z depth semantics.
//
// Build (MinGW-w64):
//   g++ -std=c++17 -O2 fake_host_d3d11.cpp -o fake_host_d3d11.exe -ld3d11 -ld3dcompiler
// Run:
//   .\fake_host_d3d11.exe
//
// It creates a WARP D3D11 device, renders a full-screen triangle at two depths
// with D3D11_COMPARISON_GREATER_EQUAL, reads the pixel back, and proves the
// nearer draw wins in both submission orders. This is the 2-second check for
// "is my host depth convention reversed-Z?" without launching a game.
#include <d3d11.h>
#include <d3dcompiler.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>

template <class T>
struct Com {
    T* p = nullptr;
    ~Com() { if (p) p->Release(); }
    T** operator&() { return &p; }
    T* operator->() const { return p; }
    explicit operator bool() const { return p != nullptr; }
    void reset() { if (p) { p->Release(); p = nullptr; } }
};

static const char* kShader = R"(
cbuffer Params : register(b0) { float g_depth; float3 g_color; };
struct VSOut { float4 pos : SV_Position; };
VSOut VSMain(uint id : SV_VertexID) {
    float2 uv = float2((id << 1) & 2, id & 2);
    VSOut o;
    o.pos = float4(uv * float2(2.0, -2.0) + float2(-1.0, 1.0), g_depth, 1.0);
    return o;
}
float4 PSMain(VSOut i) : SV_Target { return float4(g_color, 1.0); }
)";

struct Params {
    float depth;
    float color[3];
};

static bool ok(HRESULT hr, const char* what) {
    if (FAILED(hr)) {
        std::printf("FAIL %s hr=0x%08lX\n", what, static_cast<unsigned long>(hr));
        return false;
    }
    return true;
}

static bool compile(const char* entry, const char* target, Com<ID3DBlob>& blob) {
    Com<ID3DBlob> error;
    HRESULT hr = D3DCompile(kShader, std::strlen(kShader), nullptr, nullptr, nullptr, entry, target,
                            D3DCOMPILE_OPTIMIZATION_LEVEL1, 0, &blob, &error);
    if (FAILED(hr)) {
        std::printf("FAIL compile %s: %s\n", entry,
                    error ? static_cast<const char*>(error->GetBufferPointer()) : "unknown");
        return false;
    }
    return true;
}

static float read_red(ID3D11DeviceContext* ctx, ID3D11Texture2D* target, ID3D11Texture2D* staging) {
    ctx->CopyResource(staging, target);
    D3D11_MAPPED_SUBRESOURCE map{};
    if (FAILED(ctx->Map(staging, 0, D3D11_MAP_READ, 0, &map))) return -1.0f;
    const float* pixel = static_cast<const float*>(map.pData);
    const float red = pixel[0];
    ctx->Unmap(staging, 0);
    return red;
}

int main() {
    Com<ID3D11Device> device;
    Com<ID3D11DeviceContext> ctx;
    D3D_FEATURE_LEVEL level{};
    HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, 0,
                                   nullptr, 0, D3D11_SDK_VERSION, &device, &level, &ctx);
    if (FAILED(hr)) {
        std::printf("FAIL D3D11CreateDevice WARP hr=0x%08lX\n", static_cast<unsigned long>(hr));
        return 1;
    }
    std::printf("WARP device created, feature level 0x%X\n", level);
    Com<ID3DBlob> vsBlob, psBlob;
    if (!compile("VSMain", "vs_5_0", vsBlob) || !compile("PSMain", "ps_5_0", psBlob)) return 1;
    Com<ID3D11VertexShader> vs;
    Com<ID3D11PixelShader> ps;
    if (FAILED(device->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, &vs)) ||
        FAILED(device->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, &ps))) {
        std::printf("FAIL create shaders\n");
        return 1;
    }

    D3D11_TEXTURE2D_DESC colorDesc{};
    colorDesc.Width = 4;
    colorDesc.Height = 4;
    colorDesc.MipLevels = 1;
    colorDesc.ArraySize = 1;
    colorDesc.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
    colorDesc.SampleDesc.Count = 1;
    colorDesc.Usage = D3D11_USAGE_DEFAULT;
    colorDesc.BindFlags = D3D11_BIND_RENDER_TARGET;
    Com<ID3D11Texture2D> color;
    if (!ok(device->CreateTexture2D(&colorDesc, nullptr, &color), "color texture")) return 1;
    Com<ID3D11RenderTargetView> rtv;
    if (!ok(device->CreateRenderTargetView(color.p, nullptr, &rtv), "rtv")) return 1;

    D3D11_TEXTURE2D_DESC depthDesc = colorDesc;
    depthDesc.Format = DXGI_FORMAT_D32_FLOAT;
    depthDesc.BindFlags = D3D11_BIND_DEPTH_STENCIL;
    Com<ID3D11Texture2D> depth;
    if (!ok(device->CreateTexture2D(&depthDesc, nullptr, &depth), "depth texture")) return 1;
    Com<ID3D11DepthStencilView> dsv;
    if (!ok(device->CreateDepthStencilView(depth.p, nullptr, &dsv), "dsv")) return 1;

    D3D11_TEXTURE2D_DESC stagingDesc = colorDesc;
    stagingDesc.Usage = D3D11_USAGE_STAGING;
    stagingDesc.BindFlags = 0;
    stagingDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    Com<ID3D11Texture2D> staging;
    if (!ok(device->CreateTexture2D(&stagingDesc, nullptr, &staging), "staging texture")) return 1;

    D3D11_DEPTH_STENCIL_DESC dsDesc{};
    dsDesc.DepthEnable = TRUE;
    dsDesc.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ALL;
    dsDesc.DepthFunc = D3D11_COMPARISON_GREATER_EQUAL;  // reversed-Z
    Com<ID3D11DepthStencilState> dsState;
    if (!ok(device->CreateDepthStencilState(&dsDesc, &dsState), "depth state")) return 1;

    D3D11_BUFFER_DESC cbDesc{};
    cbDesc.ByteWidth = sizeof(Params);
    cbDesc.Usage = D3D11_USAGE_DYNAMIC;
    cbDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
    cbDesc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    Com<ID3D11Buffer> cb;
    if (!ok(device->CreateBuffer(&cbDesc, nullptr, &cb), "constant buffer")) return 1;

    auto draw = [&](float z, float r, float g, float b) {
        D3D11_MAPPED_SUBRESOURCE map{};
        if (FAILED(ctx->Map(cb.p, 0, D3D11_MAP_WRITE_DISCARD, 0, &map))) return false;
        auto* p = static_cast<Params*>(map.pData);
        p->depth = z;
        p->color[0] = r;
        p->color[1] = g;
        p->color[2] = b;
        ctx->Unmap(cb.p, 0);
        ctx->Draw(3, 0);
        return true;
    };

    const float clearColor[4] = {0, 0, 0, 1};
    const float clearDepth = 0.0f;  // reversed-Z far plane
    ctx->ClearRenderTargetView(rtv.p, clearColor);
    ctx->ClearDepthStencilView(dsv.p, D3D11_CLEAR_DEPTH, clearDepth, 0);
    ctx->OMSetRenderTargets(1, &rtv.p, dsv.p);
    ctx->OMSetDepthStencilState(dsState.p, 0);
    D3D11_VIEWPORT vp{0, 0, 4, 4, 0, 1};
    ctx->RSSetViewports(1, &vp);
    ctx->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    ctx->VSSetShader(vs.p, nullptr, 0);
    ctx->PSSetShader(ps.p, nullptr, 0);
    ctx->VSSetConstantBuffers(0, 1, &cb.p);
    ctx->PSSetConstantBuffers(0, 1, &cb.p);

    // Near (0.9) then far (0.1): the far draw must fail the depth test.
    if (!draw(0.9f, 1, 0, 0) || !draw(0.1f, 0, 0, 1)) return 1;
    float red = read_red(ctx.p, color.p, staging.p);
    if (!(red > 0.9f)) {
        std::printf("FAIL near-then-far: red=%.3f (expected the near draw to win)\n", red);
        return 1;
    }
    std::printf("PASS near-then-far red=%.3f\n", red);

    // Far (0.1) then near (0.9): the near draw must overwrite.
    ctx->ClearRenderTargetView(rtv.p, clearColor);
    ctx->ClearDepthStencilView(dsv.p, D3D11_CLEAR_DEPTH, clearDepth, 0);
    if (!draw(0.1f, 0, 0, 1) || !draw(0.9f, 1, 0, 0)) return 1;
    red = read_red(ctx.p, color.p, staging.p);
    if (!(red > 0.9f)) {
        std::printf("FAIL far-then-near: red=%.3f (expected the near draw to win)\n", red);
        return 1;
    }
    std::printf("PASS far-then-near red=%.3f\n", red);
    std::printf("PASS reversed-Z GREATER_EQUAL semantics\n");
    return 0;
}
