if ($server['sni'] || $server['plugin'] === 'shadow-tls') {
    $server['client-fingerprint'] = 'chrome';
}