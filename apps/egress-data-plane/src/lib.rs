use spin_sdk::http::{IntoResponse, Request, Response};
use spin_sdk::http_component;

#[http_component]
fn handle(req: Request) -> anyhow::Result<impl IntoResponse> {
    match req.path() {
        "/watm/manifest.json" => Ok(Response::builder()
            .status(200)
            .header("content-type", "application/json")
            .body(include_str!("../watmd/manifest.json"))  // {version, sha256, ed25519_sig, params}
            .build()),
        "/watm/current" => Ok(Response::builder()
            .status(200)
            .header("content-type", "application/wasm")
            .header("x-watm-version", "2024.08-tls-mimic")
            .header("x-watm-sig", include_str!("../watmd/current.sig"))
            .body(include_bytes!("../watmd/current.wasm").to_vec())
            .build()),
        _ => Ok(Response::new(404, "not found")),
    }
}
