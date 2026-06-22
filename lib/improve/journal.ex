defmodule Improve.Journal do
  use Ash.Domain,
    otp_app: :improve

  resources do
    resource Improve.Journal.EventInstance do
      define :log_event, action: :log
      define :get_event, action: :read, get_by: [:id]
      define :list_events, action: :read
      define :void_event, action: :void
      define :mark_event_corrected, action: :mark_corrected
    end

    resource Improve.Journal.EventItemLink do
      define :create_event_item_link, action: :create
      define :list_event_item_links, action: :read
    end

    resource Improve.Journal.ItemEffect do
      define :create_item_effect, action: :create
      define :list_item_effects, action: :read
      define :void_item_effect, action: :void
    end
  end
end
