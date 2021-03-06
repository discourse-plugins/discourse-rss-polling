# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DiscourseRssPolling::FeedSetting do
  SiteSetting.rss_polling_enabled = true
  let(:feed_url) { 'https://blog.discourse.org/feed/' }
  let(:author) { Fabricate(:user) }
  let(:feed_setting) { DiscourseRssPolling::FeedSetting.new(feed_url: feed_url, author_username: author.username) }
  let(:poll_feed_job) { Jobs::DiscourseRssPolling::PollFeed }

  describe '#poll' do
    context 'inline: false' do
      before do
        SiteSetting.queue_jobs = true
      end

      it 'enqueues a Jobs::DiscourseRssPolling::PollFeed job with the correct arguments' do
        Sidekiq::Testing.fake! do
          expect { feed_setting.poll }.to change(poll_feed_job.jobs, :size).by(1)

          enqueued_job = poll_feed_job.jobs.last

          expect(enqueued_job['args'][0]['feed_url']).to eq(feed_url)
          expect(enqueued_job['args'][0]['author_username']).to eq(author.username)
        end
      end
    end

    context 'inline: true' do
      it 'polls and the feed and creates the new topics' do
        $redis.del("rss-polling-feed-polled:#{Digest::SHA1.hexdigest(feed_url)}")
        stub_request(:head, feed_url).to_return(status: 200, body: '')
        stub_request(:get, feed_url).to_return(status: 200, body: file_from_fixtures('feed.rss', 'feed'))

        expect { feed_setting.poll(inline: true) }.to change { author.topics.count }

        topic = author.topics.last

        expect(topic.title).to eq('Poll Feed Spec Fixture')
        expect(topic.first_post.raw).to include('<p>This is the body &amp; content. </p>')
        expect(topic.topic_embed.embed_url).to eq('https://blog.discourse.org/2017/09/poll-feed-spec-fixture')
      end
    end
  end
end
