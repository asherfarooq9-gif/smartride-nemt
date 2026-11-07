/** @type {import('tailwindcss').Config} */
const v = name => `rgb(var(--c-${name}) / <alpha-value>)`

module.exports = {
  darkMode: ['selector', '[data-theme="dark"]'],
  content: [
    './app/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './lib/**/*.{js,ts,jsx,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        // Colours are CSS variables (see globals.css) so light and dark share one set of names.
        // Token names are the roles (ground, raised surface, inset field), not the colours.
        panel: { DEFAULT: v('panel'), raised: v('raised'), inset: v('inset') },
        edge: { DEFAULT: v('edge'), strong: v('edge-strong') },
        ink: { DEFAULT: v('ink'), dim: v('dim') },
        lamp: { red: v('red'), amber: v('amber'), green: v('green') },
        steel: v('steel'),
        // Filled buttons with white text; darker than steel in dark mode so the text stays readable.
        accent: v('accent'),
        navy: { DEFAULT: v('accent-hover'), raised: v('accent') },
      },
      borderRadius: { md: '0.5rem', lg: '0.75rem', xl: '1rem', '2xl': '1.25rem' },
      fontFamily: {
        sans: ['var(--font-body)', 'system-ui', 'sans-serif'],
        legend: ['var(--font-body)', 'system-ui', 'sans-serif'],
      },
      letterSpacing: { legend: '0.01em' },
    },
  },
  plugins: [],
}
