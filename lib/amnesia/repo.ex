defmodule Amnesia.Repo do
  alias Amnesia.Changeset
  import Amnesia.Changeset, only: [apply_changes: 1]

  def all(module) when is_atom(module),       do: module.match!([]) |> Amnesia.Selection.values

  def all(module, query),                     do: module.match!(query) |> Amnesia.Selection.values

  def get(module, id),                        do: id |> module.coerce_key |> module.read!

  def get!(module, id),                       do: id |> module.coerce_key |> module.read! || raise Amnesia.NoResultsError

  def get_by(module, query),                  do: module.match!(query) |> Amnesia.Selection.values |> one_value

  def get_by!(module, query),                 do: module.match!(query) |> Amnesia.Selection.values |> one_value || raise Amnesia.NoResultsError

  def delete(%{__struct__: module} = model),  do: module.delete!(model)

  def delete!(%{__struct__: module} = model), do: module.delete!(model)

  def delete(module, id),                     do: id |> module.coerce_key |> module.delete!

  def insert(%Changeset{valid?: true} = changeset), do: changeset |> apply_changes |> insert
  def insert(%Changeset{} = changeset), do: {:error, changeset}
  def insert(%{__struct__: module} = model),  do: {:ok, model |> inserted_stamp |> module.write!}

  def insert!(%Changeset{} = changeset), do: changeset |> apply_changes |> insert!
  def insert!(%{__struct__: module} = model), do: model |> inserted_stamp |> module.write!

  def update(%Changeset{valid?: true} = changeset), do: changeset |> apply_changes |> update
  def update(%Changeset{} = changeset), do: {:error, changeset}
  def update(%{__struct__: module} = model),  do: {:ok, model |> updated_stamp |> module.write!}

  def update!(%Changeset{} = changeset), do: changeset |> apply_changes |> update!
  def update!(%{__struct__: module} = model), do: model |> updated_stamp |> module.write!

  def preload(model, _),                      do: model  # FIXME: implement this

  def one_value(nil), do: nil
  def one_value([]), do: nil
  def one_value([one]), do: one
  def one_value(other) do
    raise Amnesia.MultipleResultsError, count: length(other)
  end

  defp inserted_stamp(%{inserted_at: _} = model), do: %{model | inserted_at: timestamp}
  defp inserted_stamp(model), do: model

  defp updated_stamp(%{updated_at: _} = model), do: %{model | updated_at: timestamp}
  defp updated_stamp(model), do: model

  def timestamp, do: :os.system_time(:seconds)
end
