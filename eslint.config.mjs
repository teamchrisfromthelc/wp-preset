// ESLint flat config (ESLint 9+) using WordPress rules.
// Requires @wordpress/eslint-plugin in devDependencies.
import wordpress from '@wordpress/eslint-plugin';

export default [
	...wordpress.configs.recommended,
	{
		ignores: [
			'build/**',
			'dist/**',
			'vendor/**',
			'node_modules/**',
			'**/*.min.js',
		],
	},
	{
		languageOptions: {
			globals: {
				wp: 'readonly',
				jQuery: 'readonly',
				ajaxurl: 'readonly',
			},
		},
	},
];
