class AddDetailsToMovies < ActiveRecord::Migration[7.1]
  def change
    add_column :movies, :poster_url, :string
    add_column :movies, :tagline, :string
    add_column :movies, :summary, :text
    add_column :movies, :content_rating, :string
    add_column :movies, :audience_rating, :decimal
    add_column :movies, :audience_rating_image, :string
    add_column :movies, :rating, :decimal
    add_column :movies, :rating_image, :string
  end
end
