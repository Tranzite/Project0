# A module with helperfunctions to app.rb
module Helper
    # Connects to the database with the provided path
    #
    # @param [String] path Path to the database.
    #
    # @return Database
    def connect_db(path)
        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        return db
    end

    # Logs in the user
    #
    # @param [String] username
    # @param [String] password
    #
    # @return [Hash]
    #  * :id [Integer] if successful login
    #  * :error [String] if failed login
    def login(username, password)
        db = connect_db("db/webshop.db")
        params = [username, password]
        is_valid(params)
        result = db.execute("SELECT * FROM users WHERE username=?", username).first
        if result != nil
            password_digest = result["password_digest"]
            id = result["id"]
            if BCrypt::Password.new(password_digest) == password
                session[:user] = username
                session[:id] = id
                redirect('/elever')
            else
                session[:error] = "Fel lösenord eller användarnamn. Försök igen."
                redirect('/error')
            end
        else
            session[:error] = "Fel lösenord eller användarnamn. Försök igen."
            redirect('/error')
        end
    end

    # Registers the user
    #
    # @param [String] username
    # @param [String] password
    # @param [String] password_confirm
    #
    # @return [Hash]
    #  * :error if failed login
    def register(username, password, password_confirm)
        db = connect_db("db/webshop.db")
        
        params = [username, password, password_confirm]
        is_valid(params)

        result = db.execute("SELECT id FROM users WHERE username=?", username)
    
        if result.empty?
            if password == password_confirm
                password_digest = BCrypt::Password.create(password)
                db.execute("INSERT INTO users (username,password_digest) VALUES (?,?)",username,password_digest)
                redirect('/login')
            else
                session[:error] = "Lösenorden matchade inte. Försök igen."
                redirect('/error')
            end
        else
            session[:error] = "Användarnamnet är upptaget. Försök igen."
            redirect('/error')
        end
    end

    # Checks if the parameters is nil or empty
    #
    # @params [Array] params Array of the parameters
    #
    # @return [Hash]
    #  * :error If a parameter was missed
    def is_valid(params)
        i = 0
        while params.length > i
            p params[i]
            if params[i] == nil || params[i] == ""
                session[:error] = "Du missade en parameter! Försök igen."
                redirect('/error')
            end
            i += 1
        end
    end
end