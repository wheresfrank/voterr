# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2024_08_29_030355) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "movies", force: :cascade do |t|
    t.string "title"
    t.string "plex_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "poster_url"
    t.string "tagline"
    t.text "summary"
    t.string "content_rating"
    t.decimal "audience_rating"
    t.string "audience_rating_image"
    t.decimal "rating"
    t.string "rating_image"
    t.string "genres", default: [], array: true
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_movies_on_user_id"
  end

  create_table "movies_sessions", id: false, force: :cascade do |t|
    t.bigint "movie_id", null: false
    t.bigint "session_id", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "session_token"
    t.string "winner_type"
    t.bigint "winner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "session_name"
    t.index ["user_id"], name: "index_sessions_on_user_id"
    t.index ["winner_type", "winner_id"], name: "index_sessions_on_winner"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "plex_token"
    t.string "plex_client_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "plex_section_id"
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "movie_id", null: false
    t.bigint "session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "guest_name"
    t.index ["movie_id"], name: "index_votes_on_movie_id"
    t.index ["session_id"], name: "index_votes_on_session_id"
    t.index ["user_id"], name: "index_votes_on_user_id"
  end

  add_foreign_key "movies", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "votes", "movies"
  add_foreign_key "votes", "sessions"
  add_foreign_key "votes", "users"
end
