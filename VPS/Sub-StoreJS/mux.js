if (($server['type'] !== 'anytls' && $server['type'] !== 'ss') || ($server['type'] === 'ss' && ($server['sni'] || $server['plugin'] === 'shadow-tls'))) {
  $server.smux = {
    "enabled": true,
    "protocol": "h2mux",
    "padding": true
  };
}