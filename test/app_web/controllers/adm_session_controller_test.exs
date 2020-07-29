defmodule AppWeb.AdmSessionControllerTest do
  use AppWeb.ConnCase, async: true

  import App.AccountsFixtures

  setup do
    %{adm: adm_fixture()}
  end

  describe "GET /admins/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, Routes.adm_session_path(conn, :new))
      response = html_response(conn, 200)

      assert response =~
               "\n<div class=\"text-center mt-24\">\n   <div class=\"flex items-center justify-center\">\n      <svg fill=\"none\" viewBox=\"0 0 24 24\" class=\"w-12 h-12 text-blue-500\" stroke=\"currentColor\">\n         <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\"\n            d=\"M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z\" />\n      </svg>\n   </div>\n   <h2 class=\"text-4xl tracking-tight\">\n      Faça login na sua conta\n   </h2>\n   <span class=\"text-sm\">ou\n         <strong class=\"text-blue-500\">\n<a href=\"/admins/register\">register a new account</a>         </strong>\n   </span>\n</div>"

      assert response =~ "Log in</a>"
      assert response =~ "Register</a>"
    end

    test "redirects if already logged in", %{conn: conn, adm: adm} do
      conn = conn |> log_in_adm(adm) |> get(Routes.adm_session_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /admins/log_in" do
    test "logs the adm in", %{conn: conn, adm: adm} do
      conn =
        post(conn, Routes.adm_session_path(conn, :create), %{
          "adm" => %{"email" => adm.email, "password" => valid_adm_password()}
        })

      assert get_session(conn, :adm_token)
      assert redirected_to(conn) =~ "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ adm.email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "logs the adm in with remember me", %{conn: conn, adm: adm} do
      conn =
        post(conn, Routes.adm_session_path(conn, :create), %{
          "adm" => %{
            "email" => adm.email,
            "password" => valid_adm_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["adm_remember_me"]
      assert redirected_to(conn) =~ "/"
    end

    test "emits error message with invalid credentials", %{conn: conn, adm: adm} do
      conn =
        post(conn, Routes.adm_session_path(conn, :create), %{
          "adm" => %{"email" => adm.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ ""
      assert response =~ "Invalid e-mail or password"
    end
  end

  describe "DELETE /admins/log_out" do
    test "logs the adm out", %{conn: conn, adm: adm} do
      conn = conn |> log_in_adm(adm) |> delete(Routes.adm_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :adm_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the adm is not logged in", %{conn: conn} do
      conn = delete(conn, Routes.adm_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :adm_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
