# Cloudflare Tunnel

> **Source:** https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/

Cloudflare Tunnel provides you with a secure way to connect your resources to Cloudflare without a publicly routable IP address. With Tunnel, you do not send traffic to an external IP — instead, a lightweight daemon in your infrastructure (`cloudflared`) creates [outbound-only connections](#outbound-only-connections) to Cloudflare's global network. Cloudflare Tunnel can connect HTTP web servers, [SSH servers](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/), [remote desktops](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/rdp/), and other protocols safely to Cloudflare. This way, your origins can serve traffic through Cloudflare without being vulnerable to attacks that bypass Cloudflare.

Refer to our [reference architecture](https://developers.cloudflare.com/reference-architecture/architectures/sase/) for details on how to implement Cloudflare Tunnel into your existing infrastructure.

## How it works

`cloudflared` establishes [outbound connections](#outbound-only-connections) (tunnels) between your resources and Cloudflare's global network. Tunnels are persistent objects that route traffic to DNS records. Within the same tunnel, you can run as many `cloudflared` processes (connectors) as needed. These processes will establish connections to Cloudflare and send traffic to the nearest Cloudflare data center.

![How an HTTP request reaches a private application connected with Cloudflare Tunnel](https://developers.cloudflare.com/_astro/handshake.eh3a-Ml1_1IcAgC.webp)

### Outbound-only connections

Cloudflare Tunnel uses an outbound-only connection model to enable bidirectional communication. When you install and run `cloudflared`, `cloudflared` initiates an outbound connection through your firewall from the origin to the Cloudflare global network.

Once the connection is established, traffic flows in both directions over the tunnel between your origin and Cloudflare. Most firewalls allow outbound traffic by default. `cloudflared` takes advantage of this standard by connecting out to the Cloudflare network from the server you installed `cloudflared` on. You can then configure your firewall to allow only these outbound connections and block all inbound traffic, effectively blocking access to your origin from anything other than Cloudflare. This setup ensures that all traffic to your origin is securely routed through the tunnel.

## Next steps

- Create a tunnel using the [Cloudflare dashboard](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/) or [API](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel-api/).
- [Download cloudflared](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/downloads/), the server-side daemon that connects your infrastructure to Cloudflare.
- Review useful [Tunnel terms](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/tunnel-useful-terms/) to familiarize yourself with the concepts used in Tunnel documentation.
