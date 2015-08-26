---
layout: post
title: 'Class Based Wordpress: Using Object Oriented Programming in Wordpress... and
  why!'
date: 2014-09-14 12:56:19.000000000 -07:00
---
I use WordPress a lot. It’s definitely one of the easiest ways to create a site. Yet, programming in WordPress can also be a pain. The way it’s structured promotes a lot of bad habits and its procedural nature forces you to write the same code over and over again, even though most sites share a lot of similar functionality.

There are many advantages to using WordPress and there’s a lot of really good reasons to use it as a web framework. Some of these are:

* Best admin experience out of any CMS or web framework
* Easy extensibility with plugins (although a plugin is rarely the solution!)
* Good Basic API for creating websites (Posts, Pages, * Taxonomies, Custom Post Types)

Some of the weaknesses WordPress has are:

* Procedural Programming
* A framework based on templates rather than models and views
* A lot of repeated code, not following DRY principal.
* No separation of data and presentation (even in the functions.php file!)
* Leads to spaghetti code
* These problems are all inter-related and are

Recently, after using some MVCs like Django, I’ve started try to MVCfy WordPress. You can see a repo with a sample theme here. The idea behind all this is to make my code more reusable by creating ‘models’ for posts, pages, custom post types and images (maybe I’ll include taxonomies in the future). These models take in an id or a post object as a parameter and then created a new object. This new object extends the default WordPress object by adding things like permalink, featured image, HTML title, custom meta, excerpt, template… etc. These are given to you for free, so there is no need to go in a call another function to get the permalink. These can also be extended to include even more data and can include methods by which custom meta (especially fields with ACF) can be cleaned and parsed.

For example, compare this:

```
$post = get_post(get_the_ID())
$post_thumbnail_id = get_post_thumbnail_id( get_the_ID() );
$post_thumbnail_url = wp_get_attachment_url($post_thumbnail_id); 
$permalink = get_permalink( get_the_ID() );
$custom_meta_1 = get_post_meta(get_the_ID(), 'custom_meta_1'); // Array
$custom_meta_2 = get_post_meta(get_the_ID(), 'custom_meta_2'); // String
echo $post->post_title;
echo '<img src="' . $post_thumbnail_url . '">';
echo '<a href="' . $permalink . '">';
echo 'Field #1: ' . $custom_meta_1[0];
echo 'Field #2: ' . $custom_meta_2->property;
```

With this:

```
$post = new Post(get_the_ID());
echo $post->post_title;
echo '<img src="' . $post->featured_image->url . '">';
echo '<a href="' . $post->permalink . '">';
echo 'Field #1: ' . $post->fields['custom_meta_1'][0];
echo 'Field #2: ' . $post->fields['custom_meta_2']->property;
```
Not only is the second one much shorter and easier to write, but it’s more readable and more consistent. By creating classes, you can create your own API that is consistent through out the whole site. This keeps your code DRY and makes it easier to read. It also makes your code easier to maintain and extend, since every time you need to make a change, you only have to make it once.

How does this `Post` model look like and how can I extend it? These models are declared as PHP Classes and they usually extend a `Single` class which does most of the work of getting and `$id` or `$object` and turning that into it’s own extended post object. To declare your model/PHP class, you only need to do this:

```
<?php
class Post extends Single {
         // Custom Meta Tags will get queried 
         // just by declaring them in this array
         // These can be set with ACF
         public $field_names = array(
         	'custom_meta_1', 'custom_meta_2');
         const CLASS_NAME = 'post';
         public function __construct($post_id_or_object) {
                 parent::__construct($post_id_or_object);
                 $this->string = $this->parseCustomMetaData();
         }
 
         // Extend your model by creating a method
         public function parseCustomMetaData () {
             $string = "";
             foreach($this->fields['custom_meta_1'] as $custom) {
                 $string += $custom;
             }
             return $custom;
         }
}
```

Now that you have your models setup, you can go on to your views. These can be very complex, or they can be very simple. Since most of your data is already structured, most of your views will be quite simple since they will just query a Post or Page. It’s important to know that views should only contain code that prepares your data for presentation, looks for data that is specific to that view, or parse the relationship between different models. It should not deal with model data directly.

For a simple post page, this would look something like this:

```
<?php 
 class PostView extends View {
     const NAME = 'PostView';
      public function __construct($post_id_or_object) {
           parent::__construct($post_id_or_object);
           $this->post = new Post($post_id_or_object);
      }
 }
```
Basically, you just create a post object using your $post_id and you’re done. For querying a page with multiple posts (all posts with custom post type `image-post` in this case), your view might look something like this:

```
<?php 
 class ImagePostArchiveView extends ArchiveView {
     const NAME = 'ImagePostArchiveView';
      public function __construct($post_id_or_object = false) {
           parent::__construct($post_id_or_object);
           if ($post_id_or_object) {
                $this->post = new Page($post_id_or_object);
           }
           $this->posts = $this->get_posts('ImagePost');
      }
 }
```
This uses a `get_posts` function declared in the `View` class where you can pass the name of your class as an argument and it returns an array of `ImagePost`s.

Now we’re only missing our template. This is by far the best part, because our template will be short, clean, and will only have our HTML. In `archive-image-post` we use the following code:

```
    <?php $view = new ImagePostArchiveView(); ?>
    <?php get_header(); ?>
      <?php foreach($view->posts as $post): ?>
        <div class="row">
           <div class="small-12 columns">
              <h1><?php echo $post->post_title; ?></h1>
           </div>
        </div>
           <div class="row">
           <div class="small-4 columns entry-content">
             <img src='<?php echo $post->image->url; ?>' />
           </div>
          <div class="small-8 columns entry-content">
             <?php echo $post->post_content; ?>
          </div>
       </div>
    <?php endforeach; ?>
    <?php get_footer(); ?>
```
As you can see, this is not that different from a regular WordPress template. We still use `get_header` and `get_footer` and we loop through some of our PHP variables. But we don’t call any PHP functions here and we have no logic and no data fetching in our templates. This is only our presentation layer.

GitHub Repo: https://github.com/thejsj/class-based-wordpress
