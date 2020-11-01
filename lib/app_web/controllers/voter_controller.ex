defmodule AppWeb.VoterController do
  use AppWeb, :controller

  alias App.Elections
  alias App.Elections.Voter

  def index(conn, params) do
    case params do
      %{"option" => "bairro", "query" => _} ->
        list_voters = Elections.list_for_bairro(params)
        page = App.Repo.paginate(list_voters, params)
        render(conn, "index.html", voters: page.entries, page: page)

      %{"option" => "sessão", "query" => _} ->
        list_voters = Elections.list_for_sessao(params)
        page = App.Repo.paginate(list_voters, params)
        render(conn, "index.html", voters: page.entries, page: page)

      %{"option" => "zona", "query" => _} ->
        list_voters = Elections.list_for_zona(params)
        page = App.Repo.paginate(list_voters, params)
        render(conn, "index.html", voters: page.entries, page: page)

      %{"option" => "cidade", "query" => _} ->
        list_voters = Elections.list_for_city(params)
        page = App.Repo.paginate(list_voters, params)
        render(conn, "index.html", voters: page.entries, page: page)

      %{"option" => "nome", "query" => _} ->
        list_voters = Elections.list_for_name(params)
        page = App.Repo.paginate(list_voters, params)
        render(conn, "index.html", voters: page.entries, page: page, params: params)

      %{"option" => "líder", "query" => _} ->
        query = Elections.leaders_query(params)

        if query != [] do
          list_voters = Elections.leader_voter(query)
          page = App.Repo.paginate(list_voters, params)
          render(conn, "index.html", voters: page.entries, page: page)
        else
          conn
          |> put_flash(:error, "Líder não existe.")
          |> redirect(to: Routes.voter_path(conn, :index))
        end

      %{} ->
        list_voters = Elections.list_voters(params)
        page = App.Repo.paginate(list_voters, params)
        render(conn, "index.html", voters: page.entries, page: page)
    end
  end

  def new(conn, _params) do
    leaders = Elections.list_leaders()
    changeset = Elections.change_voter(%Voter{})
    render(conn, "new.html", changeset: changeset, leaders: leaders)
  end

  def create(conn, %{"voter" => voter_params}) do
    case Elections.create_voter(voter_params) do
      {:ok, voter} ->
        conn
        |> put_flash(:info, "Eleitor criado com sucesso.")
        |> redirect(to: Routes.voter_path(conn, :show, voter))

      {:error, %Ecto.Changeset{} = changeset} ->
        leaders = Elections.list_leaders()
        render(conn, "new.html", changeset: changeset, leaders: leaders)
    end
  end

  def show(conn, %{"id" => id}) do
    voter = Elections.get_voter!(id)
    leader = Elections.get_leader!(voter.leader_by_id)
    render(conn, "show.html", voter: voter, leader: leader)
  end

  def edit(conn, %{"id" => id}) do
    voter = Elections.get_voter!(id)
    changeset = Elections.change_voter(voter)
    render(conn, "edit.html", voter: voter, changeset: changeset)
  end

  def update(conn, %{"id" => id, "voter" => voter_params}) do
    voter = Elections.get_voter!(id)
    leader_id = search_leader_id(voter_params)
    voter_params = Map.put(voter_params, "leader_by_id", leader_id)

    case Elections.update_voter(voter, voter_params) do
      {:ok, voter} ->
        conn
        |> put_flash(:info, "Eleitor atualizado com sucesso.")
        |> redirect(to: Routes.voter_path(conn, :show, voter))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", voter: voter, changeset: changeset)
    end
  end

  defp search_leader_id(params) do
    leader_name = params["leader_by_id"]

    if String.match?(leader_name, ~r/\d/) == true do
      leader_name
    else
      leader = Elections.leaders_query(%{"query" => leader_name})
      [head | _tail] = leader
      leader = head.id
      leader
    end
  end

  def delete(conn, %{"id" => id}) do
    voter = Elections.get_voter!(id)
    {:ok, _voter} = Elections.delete_voter(voter)

    conn
    |> put_flash(:info, "Eleitor excluído com sucesso.")
    |> redirect(to: Routes.voter_path(conn, :index))
  end

  def export(conn, _) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"download.csv\"")
    |> send_resp(200, csv_content())
  end

  defp csv_content do
    __dados =
      [['lider', 'nome', 'endereco', 'telefone', 'zona'], ['Frank', 'Gissandro', 'CJ Paar Al. Portel', '91999999', '072']]
      |> CSV.encode()
      |> Enum.to_list()
      |> to_string
  end

  # def posts(conn, _params) do
  # name = from v in "voters", select: v.name

  # posts = Repo.all(name)

  # conn
  # |> put_resp_content_type("text/xlsx")
  # |> put_resp_header("content-disposition", "attachment; filename=posts_report")
  # |> render("report.xlsx", %{posts: posts})
  # end
end
