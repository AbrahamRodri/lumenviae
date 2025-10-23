/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './lib/**/*.{ex,exs,heex}',
    './assets/js/**/*.js',
  ],
  theme: {
    extend: {
      colors: {
        navy: {
          DEFAULT: '#003b5c',
          dark: '#002840',
          light: '#004d75',
        },
        gold: {
          DEFAULT: '#b18b49',
          light: '#c9a96b',
          dark: '#8f6e38',
        },
        cream: {
          DEFAULT: '#faf2e6',
          dark: '#f0e5d0',
        },
      },
      fontFamily: {
        'roman-uncial': ['Roman Uncial Modern', 'serif'],
        'ovo': ['Ovo', 'serif'],
        'work-sans': ['Work Sans', 'sans-serif'],
        'garamond': ['EB Garamond', 'serif'],
        'cinzel-decorative': ['Roman Uncial Modern', 'serif'],
        'cinzel': ['Ovo', 'serif'],
        'cormorant': ['EB Garamond', 'serif'],
        'crimson': ['Work Sans', 'sans-serif'],
      },
      borderWidth: {
        '3': '3px',
      },
      boxShadow: {
        'soft': '0 2px 8px rgba(0, 59, 92, 0.1)',
        'ornate': '0 4px 12px rgba(0, 59, 92, 0.15)',
      },
      maxWidth: {
        'boxed': '1365px',
      },
      spacing: {
        'contemplative': '2.5rem',
        'section': '3rem',
      },
      height: {
        'nav': '100px',
      },
    },
  },
}
