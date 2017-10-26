#! /usr/bin/env ruby

require 'httparty'
require 'json'
require 'nokogiri'

# TODO
# replace dumb date parsing with query string parsing
# create actual date objects
# emailer
# optimize: parallel gets

class Film
  attr_accessor :title, :link, :dates, :blurb
end

@metrograph = []
@ifc = []
@quad = []
@filmlinc = []

def get_doc(url)
  page = HTTParty.get(url)
  Nokogiri::HTML(page) { |c| c.noblanks }
end

# (fast) everything on one page :)
def scrape_metrograph
  doc = get_doc('http://metrograph.com/film')

  @metrograph = doc.css('h4.title.narrow a').map { |link|
    # get the date selector element
    selector = doc.css("a[href=\"#{link['href']}\"]~div.text select.date")
    # get links for first and last date, links end with YYYY-MM-DD
    dates = selector.children.map { |e|
      e['value'].split('/').last
    }
    # get the summary
    blurb = doc.css("a[href=\"#{link['href']}\"]~div.text div.summary").text.strip!

    film = Film.new
    film.title = link.text
    film.link = link['href']
    film.dates = dates
    film.blurb = blurb
    film
  }
end

# (slow) get movie links, go to each page
def scrape_ifc
  doc = get_doc('http://www.ifccenter.com')

  links = doc.css("div.details a[href*=\"ifccenter.com/films\"]").map { |l|
    l['href']
  }.uniq

  # navigate to each film page
  for link in links
    doc = get_doc(link)

    # get the title
    title = doc.css("h1.title").text

    # get dates from movietickets links
    # https://www.movietickets.com/pre_purchase.asp?house_id=9598&movie_id=249296&rdate=10-25-2017
    dates = doc.css("ul.schedule-list a[href*=\"movietickets.com/pre_purchase.asp\"]").map { |l|
      link = l['href']
      link.split('=').last
    }.uniq

    if dates.length == 0
      # films that are coming soon don't have dates
      next
    end

    # get twitter description
    twitter_desc = doc.css("meta[name=\"twitter:description\"]").first['content']

    film = Film.new
    film.title = title
    film.link = link
    film.dates = dates
    film.blurb = twitter_desc
    @ifc.push(film)
  end
end

# (slow) get movie links, go to each page
def scrape_quad
  doc = get_doc('https://quadcinema.com')

  links = doc.css("a[href*=\"quadcinema.com/film\"]").map { |l|
    l['href']
  }.uniq

  for link in links
    doc = get_doc(link)

    # get the title
    title = doc.css("h1.film-title").first.text

    # get dates from fandango links
    # http://www.fandango.com/quadcinema_aaefp/theaterpage?date=2017-10-31
    dates = doc.css("a[href*=\"fandango.com/quadcinema\"]").map { |l|
      link = l['href']
      link.split('=').last
    }.uniq

    # blurb is the first p in the synopsis div
    blurb = doc.css("div[class*=\"synopsis\"] p").first.text

    film = Film.new
    film.title = title
    film.dates = dates
    film.link = link
    film.blurb = blurb
    @quad.push(film)
  end
end

# (slow) get movie links from calendar page, go to each page
def scrape_filmlinc
  doc = get_doc('https://www.filmlinc.org/calendar/')

  links = doc.css("a[href*=\"filmlinc.org/films\"]").map { |l|
    l['href']
  }.uniq

  for link in links
    doc = get_doc(link)

    # title is in the <title> tag
    title = doc.css("title").first.text

    # get dates (h4 in showtimes div)
    # Thursday, October 26 format
    dates = doc.css("div.day-showtimes h4").map { |e|
      e.text
    }.uniq

    # blurb is the first p in the synopsis div
    blurb = doc.css("div.post-content").first.text.strip!

    film = Film.new
    film.title = title
    film.dates = dates
    film.link = link
    film.blurb = blurb
    @filmlinc.push(film)
  end
end

# scrape_metrograph
# puts @metrograph.map { |f| f.inspect }

# scrape_ifc
# puts @ifc.map { |f| f.inspect }

# scrape_quad
# puts @quad.map { |f| f.inspect }

scrape_filmlinc
puts @filmlinc.map { |f| f.inspect }

=begin
CSS selectors:
descendant selector (space)
child selector (>)
adjacent sibling selector (+)
general sibling selector (~)
=end

# FilmLinc has a JSON object on https://www.filmlinc.org/now-playing/ with showing info
# will need deduping

=begin METROGRAPH
# pretty straightforward to parse
<div class="film">

<a href="http://metrograph.com/film/film/1072/stand-by-me" class="image"><img src="/uploads/films/sm5-1504625651-600x310.jpg" width="600" height="310" alt="STAND BY ME " /></a>

<div class="text">

<select class="date" disabled="disabled">
<option value="http://metrograph.com/film/film/times/1072/2017-10-27">Friday October 27</option>
<option value="http://metrograph.com/film/film/times/1072/2017-10-28">Saturday October 28</option>
<option value="http://metrograph.com/film/film/times/1072/2017-10-29">Sunday October 29</option>
</select>

<h4 class="title narrow"><a href="http://metrograph.com/film/film/1072/stand-by-me">STAND BY ME </a></h4>

<div class="showtimes">
<a href="https://t.metrograph.com/Ticketing/visSelectTickets.aspx?cinemacode=9999&txtSessionId=6092">10:30pm</a>						<noscript>
<div class="nojs"><a href="/calendar?film=1072">All dates &amp; times&hellip;</a></div>
</noscript>
</div>

<div class="details">
DIRECTOR: ROB REINER <br />						<span class="specs">1986 / 89min / DCP</span>
</div>
<div class="summary">
Adapting King’s novella “The Body,” Reiner created this rightly beloved, clear-eyed evocation of 1950s America, starring River Phoenix, Wil Wheaton, Corey Feldman, and Jerry O’Connell as a group of adolescent friends in small-town Oregon who set out to find a missing boy who is believed dead. 					</div>
<div class="more">
<a href="http://metrograph.com/film/film/1072/stand-by-me">MORE&hellip;</a>
</div>
</div>
</div>
=end
