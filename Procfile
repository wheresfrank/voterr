web: bundle exec puma -C config/puma.rb
worker: QUEUE_DATABASE_URL=$QUEUE_DATABASE_URL bundle exec rails solid_queue:start