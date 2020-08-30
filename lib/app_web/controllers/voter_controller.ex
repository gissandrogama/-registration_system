defmodule AppWeb.VoterController do
  use AppWeb, :controller

  alias App.Elections
  alias App.Elections.Voter

  def index(conn, params) do
    case params do
      %{"query" => _} ->
        voters = Elections.list_voters(params)
        render(conn, "index.html", voters: voters)

      %{"query_leader" => _} ->
        query = Elections.leaders_query(params)
        voters = Elections.leader_voter(query)
        render(conn, "index.html", voters: voters)

      _ ->
        voters = Elections.list_voters(params)
        render(conn, "index.html", voters: voters)
    end
  end

  def new(conn, _params) do
    IO.inspect(conn.request_path)
    leaders = Elections.list_leaders()
    changeset = Elections.change_voter(%Voter{})
    render(conn, "new.html", changeset: changeset, leaders: leaders)
  end

  def create(conn, %{"voter" => voter_params}) do

    case Elections.create_voter(voter_params) do
      {:ok, voter} ->
        conn
        |> put_flash(:info, "Voter created successfully.")
        |> redirect(to: Routes.voter_path(conn, :show, voter))

        {:error, %Ecto.Changeset{} = changeset} ->
        leaders = Elections.list_leaders()
        render(conn, "new.html", changeset: changeset, leaders: leaders)
    end
  end

  def show(conn, %{"id" => id}) do
    voter = Elections.get_voter!(id)
    render(conn, "show.html", voter: voter)
  end

  def edit(conn, %{"id" => id}) do
    voter = Elections.get_voter!(id)
    changeset = Elections.change_voter(voter)
    render(conn, "edit.html", voter: voter, changeset: changeset)
  end

  def update(conn, %{"id" => id, "voter" => voter_params}) do
    voter = Elections.get_voter!(id)
    case Elections.update_voter(voter, voter_params) do
      {:ok, voter} ->
        conn
        |> put_flash(:info, "Voter updated successfully.")
        |> redirect(to: Routes.voter_path(conn, :show, voter))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", voter: voter, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    voter = Elections.get_voter!(id)
    {:ok, _voter} = Elections.delete_voter(voter)

    conn
    |> put_flash(:info, "Voter deleted successfully.")
    |> redirect(to: Routes.voter_path(conn, :index))
  end
end
