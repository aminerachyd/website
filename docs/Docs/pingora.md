---
tags:
  - pingora
  - networking
  - rust
---

# Pingora Load Balancer

## Introduction

Pingora is a [Rust library](https://github.com/cloudflare/pingora) for creating network services. It was recently released by Cloudflare as an alternative for Nginx.

These are notes following a simple walkthrough of the [quick start guide](https://github.com/cloudflare/pingora/blob/main/docs/quick_start.md) for creating a load balancer.

### Installation Notes

When installing the crate, an error suggesting that `zstd-sys` is required might appear:
- install `zstd` with package manager
- run `cargo update`

---

## Basic Server Setup

### A Simple Server

```rust
let mut server = Server::new(None).unwrap(); // The None is options to supplement to the server
server.bootstrap(); // Prepares the server with the given options

// Runs the server, this is blocking call until the server exits.
// In daemon mode, the run_forever function maybe be launched as a fork,
//  so all previously launched threads by the parent process will be lost.
server.run_forever();
```

### Loadbalancer Server

- Requires the `ProxyHttp` trait to be implemented in a struct that is similar to:

```rust
struct LB(Arc<LoadBalancer<RoundRobin>>);
```

- The only required method to implement is `upstream_peer()` which returns the address where the request should be sent to
- The `upstream_request_filter()` function modifies the request, in the example it adds a Host header after connecting to the backend but right befor sending the request header
- SNI = Server Name Indication, used by the browser (or other clients) to indicate to the server which website is requested

---

## Advanced Features

### Running as a CLI

Changing the server creation to:

```rust
let mut server = Server::new(Some(Opt::default())).unwrap();
```

Now the program can be run with arguments

```bash
cargo run -- -h
```

A configuration file can be supplied to the CLI, it's a yaml file:

```yaml
---
version: 1
threads: 2
pid_file: /tmp/load_balancer.pid
error_log: /tmp/load_balancer_err.log
upgrade_sock: /tmp/load_balancer.sock
```

### Graceful Shutdown and Restart

A restart can be done via the `-u` flag given in CLI mode to not lose connection after a graceful shutdown

```bash
pkill -SIGQUIT pingora_lb &&\
RUST_LOG=INFO cargo run -- -c conf.yaml -d -u
```

Uses an upgrade coordination socket that is indicated via the configuration file. The socket is handed over to the new created process and client connections are not lost as result.
