# https://github.com/phoenixframework/phoenix_ecto/blob/master/lib/phoenix_ecto/html.ex
if Code.ensure_loaded?(Phoenix.HTML) do
  defimpl Phoenix.HTML.FormData, for: Amnesia.Changeset do
    def to_form(changeset, opts) do
      %{params: params, model: model} = changeset
      {name, opts} = Keyword.pop(opts, :name)
      name = to_string(name || form_for_name(model))

      %Phoenix.HTML.Form{
        source: changeset,
        impl: __MODULE__,
        id: name,
        name: name,
        errors: form_for_errors(changeset.errors),
        model: model,
        params: params || %{},
        hidden: form_for_hidden(model),
        options: Keyword.put_new(opts, :method, form_for_method(model))
      }
    end

    def to_form(%{action: parent_action} = source, form, field, opts) do
      if Keyword.has_key?(opts, :default) do
        raise ArgumentError, ":default is not supported on inputs_for with changesets. " <>
                             "The default value must be set in the changeset data"
      end

      {prepend, opts} = Keyword.pop(opts, :prepend, [])
      {append, opts} = Keyword.pop(opts, :append, [])
      {name, opts} = Keyword.pop(opts, :as)
      {id, opts} = Keyword.pop(opts, :id)

      id    = to_string(id || form.id <> "_#{field}")
      name  = to_string(name || form.name <> "[#{field}]")

      case find_inputs_for_type!(source, field) do
        {:one, cast, module} ->
          changesets =
            case Map.fetch(source.changes, field) do
              {:ok, nil} -> []
              {:ok, map} when not is_nil(map) -> [validate_map!(map, field)]
              _  -> [validate_map!(assoc_from_data(source.data, field), field) || module.__struct__]
            end

          for changeset <- skip_replaced(changesets) do
            %{data: data, params: params} = changeset =
              to_changeset(changeset, parent_action, module, cast)

            %Phoenix.HTML.Form{
              source: changeset,
              impl: __MODULE__,
              id: id,
              name: name,
              errors: form_for_errors(changeset),
              data: data,
              params: params || %{},
              hidden: form_for_hidden(data),
              options: opts
            }
          end

        {:many, cast, module} ->
          changesets =
            validate_list!(Map.get(source.changes, field), field) ||
            validate_list!(assoc_from_data(source.data, field), field) ||
            []

          changesets =
            if form.params[Atom.to_string(field)] do
              changesets
            else
              prepend ++ changesets ++ append
            end

          changesets = skip_replaced(changesets)

          for {changeset, index} <- Enum.with_index(changesets) do
            %{data: data, params: params} = changeset =
              to_changeset(changeset, parent_action, module, cast)
            index_string = Integer.to_string(index)

            %Phoenix.HTML.Form{
              source: changeset,
              impl: __MODULE__,
              id: id <> "_" <> index_string,
              name: name <> "[" <> index_string <> "]",
              index: index,
              errors: form_for_errors(changeset),
              data: data,
              params: params || %{},
              hidden: form_for_hidden(data),
              options: opts
            }
          end
      end
    end

    def input_type(changeset, field) do
      type = Map.get(changeset.types, field, :string)
      type = type.type

      case type do
        :integer  -> :number_input
        :float    -> :number_input
        :decimal  -> :number_input
        :boolean  -> :checkbox
        :date     -> :date_select
        :time     -> :time_select
        :datetime -> :datetime_select
        _         -> :text_input
      end
    end

    def input_validations(changeset, field) do
      [required: field in changeset.required] ++
        for({key, validation} <- changeset.validations,
            key == field,
            attr <- validation_to_attrs(validation, field, changeset),
            do: attr)
    end

    defp assoc_from_data(data, field) do
      assoc_from_data(data, Map.fetch!(data, field), field)
    end
    defp assoc_from_data(_data, value, _field) do
      value
    end

    defp skip_replaced(changesets) do
      Enum.reject(changesets, fn
        _ -> false
      end)
    end

    defp validation_to_attrs({:length, opts}, _field, _changeset) do
      max =
        if val = Keyword.get(opts, :max) do
          [maxlength: val]
        else
          []
        end

      min =
        if val = Keyword.get(opts, :min) do
          [minlength: val]
        else
          []
        end

      max ++ min
    end

    defp validation_to_attrs({:number, opts}, field, changeset) do
      type = Map.get(changeset.types, field, :integer)
      step_for(type) ++ min_for(type, opts) ++ max_for(type, opts)
    end

    defp validation_to_attrs(_validation, _field, _changeset) do
      []
    end

    defp step_for(:integer), do: [step: 1]
    defp step_for(_other),   do: [step: "any"]

    defp max_for(type, opts) do
      cond do
        max = type == :integer && Keyword.get(opts, :less_than) ->
          [max: max - 1]
        max = Keyword.get(opts, :less_than_or_equal_to) ->
          [max: max]
        true ->
          []
      end
    end

    defp min_for(type, opts) do
      cond do
        min = type == :integer && Keyword.get(opts, :greater_than) ->
          [min: min + 1]
        min = Keyword.get(opts, :greater_than_or_equal_to) ->
          [min: min]
        true ->
          []
      end
    end

    defp find_inputs_for_type!(changeset, field) do
      case Map.fetch(changeset.types, field) do
        {:ok, {tag, %{cardinality: cardinality, on_cast: cast, related: module}}} when tag in [:embed, :assoc] ->
          {cardinality, cast, module}
        _ ->
          raise ArgumentError,
            "could not generate inputs for #{inspect field} from #{inspect changeset.data.__struct__}. " <>
            "Check the field exists and it is one of embeds_one, embeds_many, has_one, " <>
            "has_many, belongs_to or many_to_many"
      end
    end

    defp to_changeset(%Amnesia.Changeset{} = changeset, parent_action, _module, _cast),
      do: apply_action(changeset, parent_action)
    defp to_changeset(%{} = data, parent_action, _module, cast) when is_function(cast, 2),
      do: apply_action(cast.(data, %{}), parent_action)
    defp to_changeset(%{} = data, parent_action, _module, nil),
      do: apply_action(Amnesia.Changeset.change(data), parent_action)

    # If the parent changeset had no action, we need to remove the action
    # from children changeset so we ignore all errors accordingly.
    defp apply_action(changeset, nil),
      do: %{changeset | action: nil}
    defp apply_action(changeset, _action),
      do: changeset

    defp validate_list!(value, _what) when is_list(value) or is_nil(value), do: value
    defp validate_list!(value, what) do
      raise ArgumentError, "expected #{what} to be a list, got: #{inspect value}"
    end

    defp validate_map!(value, _what) when is_map(value) or is_nil(value), do: value
    defp validate_map!(value, what) do
      raise ArgumentError, "expected #{what} to be a map/struct, got: #{inspect value}"
    end

    defp form_for_hidden(model) do
      #for {k, v} <- Ecto.Model.primary_key(model), v != nil, do: {k, v}
      # a keyword list of fields that are required for submitting the form behind the scenes as hidden inputs. This information will be used by upcoming nested forms
      []
    end

    defp form_for_name(%{__struct__: module}) do
      module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
    end

    defp form_for_method(%{__struct__: module} = model) do
      if module.is_loaded(model), do: "put", else: "post"
    end

    defp form_for_method(_), do: "post"

    defp form_for_errors(errors) do
      for {attr, message} <- errors do
        {attr, form_for_error(message)}
      end
    end

    defp form_for_error(msg) when is_binary(msg), do: msg
    defp form_for_error({msg, count}) when is_binary(msg) do
      String.replace(msg, "%{count}", Integer.to_string(count))
    end
  end
end
