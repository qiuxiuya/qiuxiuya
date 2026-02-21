if ($server['type'] !== 'anytls') {
    $server.smux = {
    "enabled": true,
      "protocol": "h2mux",
      "padding": true
    };
}