ASC - A Space Combat
====================

This is a small game project for learning new tech. Repository history may be
rewritten without notice.

Install
-------

Ruby Version Manager (https://rvm.io/rvm/install/)
*  `curl -L https://get.rvm.io | bash -s stable --without-gems="rvm rubygems-bundler"`

Ruby (from rvm)
*  `rvm install 1.9.3`

node package manager (https://npmjs.org/)
*  `sudo apt-get install npm`

LiveScript (http://gkz.github.com/LiveScript/) - Install didn't seem to work,
just add 'LiveScript/bin' to path:
*  `git clone git://github.com/gkz/LiveScript.git && cd LiveScript && sudo bin/slake install`

HAML
*  `gem install haml`

SASS
*  `gem install sass`

Compass
*  `gem install compass`
*  `gem install companimation`

Node dependencies
*  `npm install`

Developing
----------

Run full build once to compile libraries and environment to `build/`
*  `grunt all`

Grunt watch to auto-compile HAML, SASS and LS changes
*  `grunt watch`

Simple way to host the code locally
* `cd build/`
* `python -m SimpleHTTPServer 8000`
* Open `http://127.0.0.1:8000/` in browser
