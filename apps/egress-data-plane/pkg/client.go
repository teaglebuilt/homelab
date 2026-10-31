import (
    "context"
    "io"
    "net"
    "os"

    "github.com/refraction-networking/water"
    _ "github.com/refraction-networking/water/transport/v0" // MUST register a version or it panics
)

func main() {
    wasm, _ := os.ReadFile(os.Getenv("WATM_PATH"))     // pulled from the Spin control plane
    bridge := os.Getenv("BRIDGE_ADDR")                 // e.g. bridge.example.com:443

    cfg := &water.Config{
            TransportModuleBin: wasm,
            NetworkDialerFunc:  net.Dial,                  // how the WATM reaches the network
    }
    cfg.ModuleConfig().InheritStdout()
    cfg.ModuleConfig().InheritStderr()

    ln, _ := net.Listen("tcp", ":1080")                // local SOCKS5 entrypoint for workloads
    for {
            client, _ := ln.Accept()
            go func() {
                    defer client.Close()
                    dialer, err := water.NewDialerWithContext(context.Background(), cfg)
                    if err != nil { return }
                    // obfuscated hop to the bridge; whatever we relay is WATM-transformed on the wire
                    up, err := dialer.DialContext(context.Background(), "tcp", bridge)
                    if err != nil { return }
                    defer up.Close()
                    go io.Copy(up, client)
                    io.Copy(client, up)
            }()
    }
}
