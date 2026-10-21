import nextVitals from 'eslint-config-next/core-web-vitals'

export default [...nextVitals, { ignores: ['.next/**', 'e2e/.auth/**', 'playwright-report/**', 'test-results/**'] }]
