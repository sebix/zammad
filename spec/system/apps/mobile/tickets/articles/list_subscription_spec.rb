# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'Mobile > Ticket > Articles List subscription', app: :mobile, authenticated_as: :agent, type: :system do
  let(:group)                { create(:group) }
  let(:customer)             { create(:customer) }
  let(:agent)                { create(:agent, groups: [group]) }
  let(:ticket)               { create(:ticket, customer: customer, group: group) }

  def create_articles(count)
    create_list(:ticket_article, count, ticket: ticket).tap do |articles|
      articles.map do |article|
        article.update!(body: "Article #{article.id}")
      end
    end
  end

  def visit_ticket
    visit "/tickets/#{ticket.id}"

    wait_for_form_to_settle('form-ticket-edit')
  end

  def wait_for_ticket_article_updates(number: 1)
    wait_for_gql('apps/mobile/pages/ticket/graphql/subscriptions/ticketArticlesUpdates.graphql', number: number)
  end

  def wait_for_ticket_articles(number: 1)
    wait_for_gql('apps/mobile/pages/ticket/graphql/queries/ticket/articles.graphql', number: number)
  end

  it 'shows a newly created article' do
    create_list(:ticket_article, 3, ticket: ticket)

    visit_ticket

    expect(page).to have_selector('[role="comment"]', count: 3)

    article = create(:ticket_article, body: 'New Article', ticket: ticket)

    wait_for_ticket_articles(number: 2)

    expect(page).to have_text(article.body)
  end

  it 'updates the list after a former visible article is deleted' do
    articles = create_articles(3)

    visit_ticket

    expect(page).to have_selector('[role="comment"]', count: 3)

    remove_article = articles.second
    remove_article_body = remove_article.body

    remove_article.destroy!

    wait_for_ticket_articles(number: 2)

    expect(page).to have_selector('[role="comment"]', count: 2)
    expect(page).to have_no_text(remove_article_body)
  end

  it 'updates the list after a non-visible article is deleted' do
    articles = create_articles(7)

    visit_ticket

    not_visible_article = articles.second

    expect(page).to have_text('load 1 more')
    expect(page).to have_no_text(not_visible_article.body)

    not_visible_article.destroy!

    wait_for_ticket_article_updates

    expect(page).to have_no_text('load 1 more')
    expect(page).to have_no_text(not_visible_article.body)
  end

  context 'when user is customer', authenticated_as: :customer do
    it 'updates the list after a former visible article at the end of the list is switched to public' do
      articles = create_articles(3)
      article = articles.last
      article.update!(internal: true)

      visit_ticket

      expect(page).to have_selector('[role="comment"]', count: 2)

      article = articles.last
      article.update!(internal: false)

      wait_for_ticket_articles(number: 2)

      expect(page).to have_selector('[role="comment"]', count: 3)
      expect(page).to have_text(article.body)
    end

    it 'updates the list after a former visible article at the end of the list is switched to internal' do
      articles = create_articles(3)

      visit_ticket

      expect(page).to have_selector('[role="comment"]', count: 3)

      article = articles.last
      article.update!(internal: true)

      wait_for_ticket_articles(number: 2)

      expect(page).to have_selector('[role="comment"]', count: 2)
      expect(page).to have_no_text(article.body)
    end

    it 'updates the list after a former visible article in between is switched to public' do
      articles = create_articles(7)
      article = articles.second
      article.update!(internal: true)

      visit_ticket

      expect(page).to have_no_text('load 1 more')
      expect(page).to have_selector('[role="comment"]', count: 6)

      article.update!(internal: false)

      wait_for_ticket_articles(number: 2)

      expect(page).to have_no_text('load 1 more')
      expect(page).to have_selector('[role="comment"]', count: 7)
      expect(page).to have_text(article.body)
    end

    it 'updates the list after a former visible article in between is switched to internal' do
      articles = create_articles(6)

      visit_ticket

      expect(page).to have_no_text('load 1 more')
      expect(page).to have_selector('[role="comment"]', count: 6)

      articles.second.update!(internal: true)

      wait_for_ticket_article_updates

      expect(page).to have_no_text('load 1 more')
      expect(page).to have_selector('[role="comment"]', count: 5)
      expect(page).to have_no_text(articles.second.body)
    end

    it 'updates the list after a non-visible article in between is switched to public' do
      articles = create_articles(8)
      article = articles.second
      article.update!(internal: true)

      visit_ticket

      expect(page).to have_text('load 1 more')
      expect(page).to have_selector('[role="comment"]', count: 6)

      article.update!(internal: false)

      wait_for_ticket_articles(number: 2)

      expect(page).to have_no_text('load 1 more')
      expect(page).to have_selector('[role="comment"]', count: 8)
    end

    it 'updates the list after a non-visible article in between is switched to internal' do
      articles = create_articles(7)

      visit_ticket

      expect(page).to have_text('load 1 more')
      expect(page).to have_selector('[role="comment"]', count: 6)

      articles.second.update!(internal: true)

      wait_for_ticket_article_updates

      expect(page).to have_no_text('load 1 more')
      expect(page).to have_selector('[role="comment"]', count: 6)
    end
  end
end
