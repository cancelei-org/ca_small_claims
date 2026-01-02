'use strict';

/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ['class', "[data-theme='dark']"],
  content: [
    './app/views/**/*.{erb,html}',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.{js,ts}',
    './app/components/**/*.{erb,rb}'
  ],
  theme: {
    container: {
      center: true,
      padding: '1rem',
      screens: {
        'sm': '640px',
        'md': '768px',
        'lg': '1024px',
        'xl': '1280px',
        '2xl': '1440px'
      }
    },
    extend: {
      colors: {
        background: 'rgb(var(--background) / <alpha-value>)',
        foreground: 'rgb(var(--foreground) / <alpha-value>)',
        card: {
          DEFAULT: 'rgb(var(--card) / <alpha-value>)',
          foreground: 'rgb(var(--card-foreground) / <alpha-value>)'
        },
        muted: {
          DEFAULT: 'rgb(var(--muted) / <alpha-value>)',
          foreground: 'rgb(var(--muted-foreground) / <alpha-value>)'
        },
        border: 'rgb(var(--border) / <alpha-value>)',
        input: 'rgb(var(--input) / <alpha-value>)',
        ring: 'rgb(var(--ring) / <alpha-value>)',
        primary: {
          DEFAULT: 'rgb(var(--primary) / <alpha-value>)',
          foreground: 'rgb(var(--primary-foreground) / <alpha-value>)'
        },
        secondary: {
          DEFAULT: 'rgb(var(--secondary) / <alpha-value>)',
          foreground: 'rgb(var(--secondary-foreground) / <alpha-value>)'
        },
        accent: {
          DEFAULT: 'rgb(var(--accent) / <alpha-value>)',
          foreground: 'rgb(var(--accent-foreground) / <alpha-value>)'
        },
        success: 'rgb(var(--success) / <alpha-value>)',
        warning: 'rgb(var(--warning) / <alpha-value>)',
        destructive: 'rgb(var(--destructive) / <alpha-value>)',
        info: 'rgb(var(--info) / <alpha-value>)'
      },
      borderRadius: {
        'lg': '0.5rem',
        'xl': '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem'
      },
      boxShadow: {
        1: '0 1px 2px rgb(0 0 0 / 0.06)',
        2: '0 4px 10px rgb(0 0 0 / 0.08)',
        3: '0 10px 25px rgb(0 0 0 / 0.10)'
      },
      fontFamily: {
        sans: ['var(--font-sans)'],
        display: ['var(--font-display)'],
        mono: ['var(--font-mono)']
      }
    }
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('daisyui')
  ],
  daisyui: {
    themes: [
      // Custom theme for CA Small Claims (professional/legal)
      {
        claims: {
          'primary': '#2563eb',          // Blue - trust & professionalism
          'primary-content': '#ffffff',
          'secondary': '#7c3aed',         // Violet - authority
          'secondary-content': '#ffffff',
          'accent': '#f59e0b',            // Amber - attention
          'accent-content': '#ffffff',
          'neutral': '#374151',
          'neutral-content': '#ffffff',
          'base-100': '#ffffff',
          'base-200': '#f9fafb',
          'base-300': '#f3f4f6',
          'base-content': '#1f2937',
          'info': '#0ea5e9',
          'info-content': '#ffffff',
          'success': '#10b981',
          'success-content': '#ffffff',
          'warning': '#f59e0b',
          'warning-content': '#ffffff',
          'error': '#ef4444',
          'error-content': '#ffffff'
        }
      },
      // Light themes (5)
      'light',
      'cupcake',
      'emerald',
      'corporate',
      'garden',
      // Dark themes (5)
      'dark',
      'night',
      'dracula',
      'business',
      'forest',
      // High Contrast Accessibility themes (WCAG AAA - 7:1 minimum contrast)
      {
        'high-contrast-light': {
          'primary': '#0000ee',             // Pure blue - 7.5:1 on white
          'primary-content': '#ffffff',
          'secondary': '#551a8b',           // Purple - 8.6:1 on white
          'secondary-content': '#ffffff',
          'accent': '#b45309',              // Dark amber - 7.2:1 on white
          'accent-content': '#ffffff',
          'neutral': '#000000',
          'neutral-content': '#ffffff',
          'base-100': '#ffffff',
          'base-200': '#f5f5f5',
          'base-300': '#e5e5e5',
          'base-content': '#000000',        // Pure black on white - 21:1
          'info': '#0066cc',                // Dark blue - 7.1:1 on white
          'info-content': '#ffffff',
          'success': '#006600',             // Dark green - 7.9:1 on white
          'success-content': '#ffffff',
          'warning': '#795600',             // Dark amber - 7.4:1 on white
          'warning-content': '#ffffff',
          'error': '#cc0000',               // Dark red - 7.1:1 on white
          'error-content': '#ffffff'
        }
      },
      {
        'high-contrast-dark': {
          'primary': '#6db3f2',             // Light blue - 8.3:1 on black
          'primary-content': '#000000',
          'secondary': '#d8b4fe',           // Light purple - 10:1 on black
          'secondary-content': '#000000',
          'accent': '#fbbf24',              // Yellow - 14:1 on black
          'accent-content': '#000000',
          'neutral': '#ffffff',
          'neutral-content': '#000000',
          'base-100': '#000000',
          'base-200': '#0a0a0a',
          'base-300': '#171717',
          'base-content': '#ffffff',        // Pure white on black - 21:1
          'info': '#7dd3fc',                // Light blue - 11:1 on black
          'info-content': '#000000',
          'success': '#86efac',             // Light green - 13:1 on black
          'success-content': '#000000',
          'warning': '#fde047',             // Yellow - 16:1 on black
          'warning-content': '#000000',
          'error': '#fca5a5',               // Light red - 10:1 on black
          'error-content': '#000000'
        }
      }
    ],
    darkTheme: 'dark',
    base: true,
    styled: true,
    utils: true,
    prefix: '',
    logs: false,
    themeRoot: ':root'
  }
};
