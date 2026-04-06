import streamlit as st
from fetch_data import fetch_data

def validate_user_ui():
    st.title("User Validation")

    username = st.text_input("Enter your username:")
    password = st.text_input("Enter your password:", type="password")

    if st.button("Validate"):
        input_params = {}
        if not username.strip():
            st.error("Username cannot be empty.")
        else:
            input_params["username"] = username

        if not password.strip():
            st.error("Password cannot be empty.")
        else:
            input_params["password"] = password.strip()

        df = fetch_data("validate_user/", input_params)

        if df is not None and not df.empty:
            st.success("User validated successfully.")
            output_string = "App User ID:" + str(df["AppUserID"].values[0]) + ", Full Name: " + df["Fullname"].values[0]
            st.write(output_string)
            st.session_state.app_user_id = df["AppUserID"].values[0]
        else:
            st.info("User validation failed.")