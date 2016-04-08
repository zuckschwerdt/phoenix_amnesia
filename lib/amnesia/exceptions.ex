defmodule Amnesia.NoResultsError do
  defexception message: "expected at least one result but got none"
end

defmodule Amnesia.MultipleResultsError do
  defexception [:message]

  def exception(opts) do
    count = Keyword.fetch!(opts, :count)

    msg = "expected at most one result but got #{count}"

    %__MODULE__{message: msg}
  end
end

defmodule Amnesia.InvalidModelError do
  defexception message: "model assertions failed"
end


defimpl Plug.Exception, for: Amnesia.NoResultsError do
  def status(_exception), do: 404
end

defimpl Plug.Exception, for: Amnesia.MultipleResultsError do
  def status(_exception), do: 404
end

defimpl Plug.Exception, for: Amnesia.InvalidModelError do
  def status(_exception), do: 500
end
