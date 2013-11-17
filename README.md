# Content Types Plugin for [DocPad](http://docpad.org)
Create multiple content types using this format in your docpad.coffee

<pre>
docpadConfig = {

	plugins:
		contenttypes:
			types: [
				name: 'Blog'
				type: 'blog'
				layout: ['default', 'data']
				categories: [
					'Technology', 'Other',
					name: 'Design'
					landing:
						layout: ['category-design-landing', 'data']
						pageSize: 10
				]
				fields:
					author: 'person'
				landing:
					layout: ['default-landing', 'data']
					pageSize: 5
			,
				name: 'FunBlog'
				type: 'funBlog',
				inherit: 'blog'
				fields:
					funText: 'text'
			,
				name: 'Person'
				type: 'person'
				noInherit: true
				fields:
					name: 'text'
					quote: 'text'
				]
....
}
</pre>



## Install

```
npm install --save docpad-plugin-contenttypes
```



## History
You can discover the history inside the `History.md` file



## License
This plugin is made ["public domain"](http://en.wikipedia.org/wiki/Public_domain) using the [Creative Commons Zero](http://creativecommons.org/publicdomain/zero/1.0/), as such before you publish your plugin you should place your desired license here and within the `LICENSE.md` file.

If you are wanting to close-source your plugin, we suggest using the following:

```
Copyright [NAME](URL). All rights reserved.
```

If you are wanting to open-source your plugin, we suggest using the following:

```
Licensed under the incredibly [permissive](http://en.wikipedia.org/wiki/Permissive_free_software_licence) [MIT License](http://creativecommons.org/licenses/MIT/)
<br/>Copyright &copy; YEAR+ [NAME](URL)
```