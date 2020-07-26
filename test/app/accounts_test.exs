defmodule App.AccountsTest do
  use App.DataCase

  alias App.Accounts
  import App.AccountsFixtures
  alias App.Accounts.{Adm, AdmToken}

  describe "get_adm_by_email/1" do
    test "does not return the adm if the email does not exist" do
      refute Accounts.get_adm_by_email("unknown@example.com")
    end

    test "returns the adm if the email exists" do
      %{id: id} = adm = adm_fixture()
      assert %Adm{id: ^id} = Accounts.get_adm_by_email(adm.email)
    end
  end

  describe "get_adm_by_email_and_password/1" do
    test "does not return the adm if the email does not exist" do
      refute Accounts.get_adm_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the adm if the password is not valid" do
      adm = adm_fixture()
      refute Accounts.get_adm_by_email_and_password(adm.email, "invalid")
    end

    test "returns the adm if the email and password are valid" do
      %{id: id} = adm = adm_fixture()

      assert %Adm{id: ^id} =
               Accounts.get_adm_by_email_and_password(adm.email, valid_adm_password())
    end
  end

  describe "get_adm!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_adm!(-1)
      end
    end

    test "returns the adm with the given id" do
      %{id: id} = adm = adm_fixture()
      assert %Adm{id: ^id} = Accounts.get_adm!(adm.id)
    end
  end

  describe "register_adm/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Accounts.register_adm(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Accounts.register_adm(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for e-mail and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_adm(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates e-mail uniqueness" do
      %{email: email} = adm_fixture()
      {:error, changeset} = Accounts.register_adm(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased e-mail too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_adm(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers admins with a hashed password" do
      email = unique_adm_email()
      {:ok, adm} = Accounts.register_adm(%{email: email, password: valid_adm_password()})
      assert adm.email == email
      assert is_binary(adm.hashed_password)
      assert is_nil(adm.confirmed_at)
      assert is_nil(adm.password)
    end
  end

  describe "change_adm_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_adm_registration(%Adm{})
      assert changeset.required == [:password, :email]
    end
  end

  describe "change_adm_email/2" do
    test "returns a adm changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_adm_email(%Adm{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_adm_email/3" do
    setup do
      %{adm: adm_fixture()}
    end

    test "requires email to change", %{adm: adm} do
      {:error, changeset} = Accounts.apply_adm_email(adm, valid_adm_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{adm: adm} do
      {:error, changeset} =
        Accounts.apply_adm_email(adm, valid_adm_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for e-mail for security", %{adm: adm} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.apply_adm_email(adm, valid_adm_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates e-mail uniqueness", %{adm: adm} do
      %{email: email} = adm_fixture()

      {:error, changeset} =
        Accounts.apply_adm_email(adm, valid_adm_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{adm: adm} do
      {:error, changeset} =
        Accounts.apply_adm_email(adm, "invalid", %{email: unique_adm_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the e-mail without persisting it", %{adm: adm} do
      email = unique_adm_email()
      {:ok, adm} = Accounts.apply_adm_email(adm, valid_adm_password(), %{email: email})
      assert adm.email == email
      assert Accounts.get_adm!(adm.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{adm: adm_fixture()}
    end

    test "sends token through notification", %{adm: adm} do
      token =
        extract_adm_token(fn url ->
          Accounts.deliver_update_email_instructions(adm, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert adm_token = Repo.get_by(AdmToken, token: :crypto.hash(:sha256, token))
      assert adm_token.adm_id == adm.id
      assert adm_token.sent_to == adm.email
      assert adm_token.context == "change:current@example.com"
    end
  end

  describe "update_adm_email/2" do
    setup do
      adm = adm_fixture()
      email = unique_adm_email()

      token =
        extract_adm_token(fn url ->
          Accounts.deliver_update_email_instructions(%{adm | email: email}, adm.email, url)
        end)

      %{adm: adm, token: token, email: email}
    end

    test "updates the e-mail with a valid token", %{adm: adm, token: token, email: email} do
      assert Accounts.update_adm_email(adm, token) == :ok
      changed_adm = Repo.get!(Adm, adm.id)
      assert changed_adm.email != adm.email
      assert changed_adm.email == email
      assert changed_adm.confirmed_at
      assert changed_adm.confirmed_at != adm.confirmed_at
      refute Repo.get_by(AdmToken, adm_id: adm.id)
    end

    test "does not update e-mail with invalid token", %{adm: adm} do
      assert Accounts.update_adm_email(adm, "oops") == :error
      assert Repo.get!(Adm, adm.id).email == adm.email
      assert Repo.get_by(AdmToken, adm_id: adm.id)
    end

    test "does not update e-mail if adm e-mail changed", %{adm: adm, token: token} do
      assert Accounts.update_adm_email(%{adm | email: "current@example.com"}, token) == :error
      assert Repo.get!(Adm, adm.id).email == adm.email
      assert Repo.get_by(AdmToken, adm_id: adm.id)
    end

    test "does not update e-mail if token expired", %{adm: adm, token: token} do
      {1, nil} = Repo.update_all(AdmToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.update_adm_email(adm, token) == :error
      assert Repo.get!(Adm, adm.id).email == adm.email
      assert Repo.get_by(AdmToken, adm_id: adm.id)
    end
  end

  describe "change_adm_password/2" do
    test "returns a adm changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_adm_password(%Adm{})
      assert changeset.required == [:password]
    end
  end

  describe "update_adm_password/3" do
    setup do
      %{adm: adm_fixture()}
    end

    test "validates password", %{adm: adm} do
      {:error, changeset} =
        Accounts.update_adm_password(adm, valid_adm_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{adm: adm} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_adm_password(adm, valid_adm_password(), %{password: too_long})

      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{adm: adm} do
      {:error, changeset} =
        Accounts.update_adm_password(adm, "invalid", %{password: valid_adm_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{adm: adm} do
      {:ok, adm} =
        Accounts.update_adm_password(adm, valid_adm_password(), %{
          password: "new valid password"
        })

      assert is_nil(adm.password)
      assert Accounts.get_adm_by_email_and_password(adm.email, "new valid password")
    end

    test "deletes all tokens for the given adm", %{adm: adm} do
      _ = Accounts.generate_adm_session_token(adm)

      {:ok, _} =
        Accounts.update_adm_password(adm, valid_adm_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(AdmToken, adm_id: adm.id)
    end
  end

  describe "generate_adm_session_token/1" do
    setup do
      %{adm: adm_fixture()}
    end

    test "generates a token", %{adm: adm} do
      token = Accounts.generate_adm_session_token(adm)
      assert adm_token = Repo.get_by(AdmToken, token: token)
      assert adm_token.context == "session"

      # Creating the same token for another adm should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%AdmToken{
          token: adm_token.token,
          adm_id: adm_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_adm_by_session_token/1" do
    setup do
      adm = adm_fixture()
      token = Accounts.generate_adm_session_token(adm)
      %{adm: adm, token: token}
    end

    test "returns adm by token", %{adm: adm, token: token} do
      assert session_adm = Accounts.get_adm_by_session_token(token)
      assert session_adm.id == adm.id
    end

    test "does not return adm for invalid token" do
      refute Accounts.get_adm_by_session_token("oops")
    end

    test "does not return adm for expired token", %{token: token} do
      {1, nil} = Repo.update_all(AdmToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_adm_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      adm = adm_fixture()
      token = Accounts.generate_adm_session_token(adm)
      assert Accounts.delete_session_token(token) == :ok
      refute Accounts.get_adm_by_session_token(token)
    end
  end

  describe "deliver_adm_confirmation_instructions/2" do
    setup do
      %{adm: adm_fixture()}
    end

    test "sends token through notification", %{adm: adm} do
      token =
        extract_adm_token(fn url ->
          Accounts.deliver_adm_confirmation_instructions(adm, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert adm_token = Repo.get_by(AdmToken, token: :crypto.hash(:sha256, token))
      assert adm_token.adm_id == adm.id
      assert adm_token.sent_to == adm.email
      assert adm_token.context == "confirm"
    end
  end

  describe "confirm_adm/2" do
    setup do
      adm = adm_fixture()

      token =
        extract_adm_token(fn url ->
          Accounts.deliver_adm_confirmation_instructions(adm, url)
        end)

      %{adm: adm, token: token}
    end

    test "confirms the e-mail with a valid token", %{adm: adm, token: token} do
      assert {:ok, confirmed_adm} = Accounts.confirm_adm(token)
      assert confirmed_adm.confirmed_at
      assert confirmed_adm.confirmed_at != adm.confirmed_at
      assert Repo.get!(Adm, adm.id).confirmed_at
      refute Repo.get_by(AdmToken, adm_id: adm.id)
    end

    test "does not confirm with invalid token", %{adm: adm} do
      assert Accounts.confirm_adm("oops") == :error
      refute Repo.get!(Adm, adm.id).confirmed_at
      assert Repo.get_by(AdmToken, adm_id: adm.id)
    end

    test "does not confirm e-mail if token expired", %{adm: adm, token: token} do
      {1, nil} = Repo.update_all(AdmToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Accounts.confirm_adm(token) == :error
      refute Repo.get!(Adm, adm.id).confirmed_at
      assert Repo.get_by(AdmToken, adm_id: adm.id)
    end
  end

  describe "deliver_adm_reset_password_instructions/2" do
    setup do
      %{adm: adm_fixture()}
    end

    test "sends token through notification", %{adm: adm} do
      token =
        extract_adm_token(fn url ->
          Accounts.deliver_adm_reset_password_instructions(adm, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert adm_token = Repo.get_by(AdmToken, token: :crypto.hash(:sha256, token))
      assert adm_token.adm_id == adm.id
      assert adm_token.sent_to == adm.email
      assert adm_token.context == "reset_password"
    end
  end

  describe "get_adm_by_reset_password_token/2" do
    setup do
      adm = adm_fixture()

      token =
        extract_adm_token(fn url ->
          Accounts.deliver_adm_reset_password_instructions(adm, url)
        end)

      %{adm: adm, token: token}
    end

    test "returns the adm with valid token", %{adm: %{id: id}, token: token} do
      assert %Adm{id: ^id} = Accounts.get_adm_by_reset_password_token(token)
      assert Repo.get_by(AdmToken, adm_id: id)
    end

    test "does not return the adm with invalid token", %{adm: adm} do
      refute Accounts.get_adm_by_reset_password_token("oops")
      assert Repo.get_by(AdmToken, adm_id: adm.id)
    end

    test "does not return the adm if token expired", %{adm: adm, token: token} do
      {1, nil} = Repo.update_all(AdmToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Accounts.get_adm_by_reset_password_token(token)
      assert Repo.get_by(AdmToken, adm_id: adm.id)
    end
  end

  describe "reset_adm_password/3" do
    setup do
      %{adm: adm_fixture()}
    end

    test "validates password", %{adm: adm} do
      {:error, changeset} =
        Accounts.reset_adm_password(adm, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{adm: adm} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.reset_adm_password(adm, %{password: too_long})
      assert "should be at most 80 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{adm: adm} do
      {:ok, updated_adm} = Accounts.reset_adm_password(adm, %{password: "new valid password"})
      assert is_nil(updated_adm.password)
      assert Accounts.get_adm_by_email_and_password(adm.email, "new valid password")
    end

    test "deletes all tokens for the given adm", %{adm: adm} do
      _ = Accounts.generate_adm_session_token(adm)
      {:ok, _} = Accounts.reset_adm_password(adm, %{password: "new valid password"})
      refute Repo.get_by(AdmToken, adm_id: adm.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%Adm{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
