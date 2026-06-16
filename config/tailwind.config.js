const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  darkMode: false,
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      colors: {
        primary: { "50": "#eff6ff", "100": "#dbeafe", "200": "#bfdbfe", "300": "#93c5fd", "400": "#60a5fa", "500": "#3b82f6", "600": "#2563eb", "700": "#1d4ed8", "800": "#1e40af", "900": "#1e3a8a", "950": "#172554" },
        theme: {
          50: '#fff1f3',
          100: '#ffe4e8',
          200: '#fecdd7',
          300: '#fda4b7',
          400: '#fa7291',
          500: '#f3406f',
          600: '#e01e5a',
          700: '#bd134b',
          800: '#9e1345',
          900: '#871441',
          950: '#4c051f'
        },

      },
      fontFamily: {
        sans: ['Inter var', ...defaultTheme.fontFamily.sans],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/aspect-ratio'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
