# frozen_string_literal: true

class PagesController < ApplicationController
  layout "landing", except: %i[robots sitemap llms]

  def home
  end

  def about
  end

  def compare
    @faqs = compare_faqs
  end

  def privacy
  end

  def robots
    expires_in 10.minutes, public: true
    render :robots, formats: :text, layout: false, content_type: "text/plain; charset=utf-8"
  end

  def sitemap
    expires_in 1.hour, public: true
    @sitemap_entries = [
      { loc: "#{SeoHelper::CANONICAL_ORIGIN}/", changefreq: "weekly", priority: "1.0" },
      { loc: "#{SeoHelper::CANONICAL_ORIGIN}/about", changefreq: "monthly", priority: "0.8" },
      { loc: "#{SeoHelper::CANONICAL_ORIGIN}/compare", changefreq: "monthly", priority: "0.8" },
      { loc: "#{SeoHelper::CANONICAL_ORIGIN}/privacy", changefreq: "yearly", priority: "0.3" }
    ]
    render :sitemap, formats: :xml, layout: false, content_type: "application/xml; charset=utf-8"
  end

  def llms
    expires_in 6.hours, public: true
    render :llms, formats: :text, layout: false, content_type: "text/plain; charset=utf-8"
  end

  private

  def compare_faqs
    [
      {
        question: "Do guests need a Plex account to vote?",
        answer: "No. Only the host signs in with Plex. Guests open the invite link and join by entering a name. They never log into Plex on Voterr."
      },
      {
        question: "Is Voterr hosted, or do I need Docker?",
        answer: "The official app at voterr.tv is hosted. You sign in with Plex OAuth in the browser. You do not run Docker, paste a Plex token, or operate a server to host movie night. The project is also open source if you prefer to self-host."
      },
      {
        question: "How does Voterr connect to Plex — OAuth or a token?",
        answer: "Voterr uses Plex OAuth (PIN/sign-in) so the host never pastes an X-Plex-Token into a .env file. That is the usual setup for self-hosted tools such as What to Watch on Plex, MovieMatch, and Swiparr."
      },
      {
        question: "How does a movie win?",
        answer: "Voterr samples titles from the host’s Plex movie library (optionally filtered by genre or unwatched). Everyone votes yes or no. When every voter has liked the same title, that movie wins. If the group does not agree, the host can pick from the top vote-getters."
      },
      {
        question: "Is Voterr the same as voterr.io?",
        answer: "No. Voterr (voterr.tv) is a Rails app for voting on movies from a Plex library. voterr.io is an unrelated Chrome extension. They do not share an author, codebase, or product."
      },
      {
        question: "Who built Voterr?",
        answer: "Frank Johnette. The source is on GitHub at github.com/wheresfrank/voterr."
      }
    ]
  end
end
