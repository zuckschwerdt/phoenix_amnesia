# Phoenix Amnesia

Integrates Phoenix with Amnesia providing an Ecto-like interface.

- Amnesia.Changeset and Amnesia.Type copied from Ecto
- Phoenix.HTML.FormData for Amnesia.Changeset copied from phoenix_html
- Amnesia.Repo emulates the Ecto interface

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add phoenix_amnesia to your list of dependencies in `mix.exs`:

        def deps do
          [{:phoenix_amnesia, "~> 0.1.0"}]
        end

  2. Ensure phoenix_amnesia is started before your application:

        def application do
          [applications: [:phoenix_amnesia]]
        end

## License

The MIT License (MIT)
