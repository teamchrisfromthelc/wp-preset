// WordPress Prettier config: tabs, single quotes, es5 trailing commas.
//
// This file is formatted by Prettier itself, so it must already satisfy the
// config it exports — hence require('...') with no inner spaces. Modern
// @wordpress/scripts uses upstream Prettier, which has no paren-spacing option;
// the spaces-inside-parens style only existed in the old wp-prettier fork and
// applies to PHP (via PHPCS), not JS.
module.exports = {
	...require('@wordpress/prettier-config'),
};
