function operator(proxies, targetPlatform, context) {
  if (targetPlatform !== 'Loon') return proxies
  return proxies.filter(p => !p['underlying-proxy'])
}