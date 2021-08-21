require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative 'model.rb'
enable :sessions
set :session_secret, 'UoRCowyRlL9sXHu'

include Helper

before do
    #p "Before KÖRS, session_user_id är #{session[:id]}."
    if session[:id] != 1
        if (request.path_info == '/klasser/new') || (request.path_info == '/klasser/:id/edit')
            session[:error] = "No permission."
            redirect('/error')
        end
    end
    if (session[:id] == nil) && (request.path_info == '/cart')
        session[:error] = "You need to log in to view this page."
        redirect('/error')
    end
end
  
# Displays error page
get('/error') do
    slim(:error)
end

# Displays landing page
get('/') do
    slim(:index)
end

get('/spel') do
    db = connect_db("db/webshop.db")
    result = db.execute("SELECT * FROM selected_classes WHERE user_id = ?",session[:id])
    empty = nil
    if result.empty?
        empty = true
    else
        empty = false
        i = 0
        result2 = []
        while i < result.length
            result2 << result[i]['class_id']
            i+=1
        end
        result3 = db.execute("SELECT * FROM students WHERE class_id IN (#{result2.join(",")})")
    end
    slim(:"games/guess",locals:{students:result3, empty:empty})
end

get ('/api/students') do
    db = connect_db("db/webshop.db")
    result = db.execute("SELECT * FROM selected_classes WHERE user_id = ?",session[:id])
    i = 0
    result2 = []
    while i < result.length
        result2 << result[i]['class_id']
        i+=1
    end
    p result2
    result3 = db.execute("SELECT * FROM students WHERE class_id IN (#{result2.join(",")})")
    p result3
    result3.to_json
end

# Displays all classes contained in the database
get('/klasser') do
    db = connect_db("db/webshop.db")
    result = db.execute("SELECT * FROM classes")
    result2 = db.execute("SELECT * FROM selected_classes WHERE user_id = ?",session[:id])
    #p result2
    #eventuellt lägga till så de är icheckade fortfarande
    slim(:"items/index",locals:{classes:result})
end

# Saves the selected classes to the account and redirects to /elever
#
# @param [Array] selected
#
# @return selected classes saved
post('/klasser/submit_classes') do
    db = connect_db("db/webshop.db")
    select_array = params['selected']
    if select_array == nil
        session[:error] = "Inga klasser valda!"
        redirect('/error')
    else
        result = db.execute("SELECT * FROM selected_classes WHERE user_id = ?",session[:id])
        if result.empty?    
            select_array.each do |selec|
                db.execute("INSERT INTO selected_classes (user_id, class_id) VALUES (?,?)",session[:id],selec)
            end
        else
            db.execute("DELETE FROM selected_classes WHERE user_id = ?",session[:id])
            select_array.each do |selec|
                db.execute("INSERT INTO selected_classes (user_id, class_id) VALUES (?,?)",session[:id],selec)
            end
        end
        redirect('/elever')
    end
end

# Displays page to create new class
get('/klasser/new') do
    db = connect_db("db/webshop.db")
    slim(:"items/new")
end

# Creates a new item and redirects to /klasser
#
# @param [String] class_name
#
# @return klass is created 
post('/klasser/new') do
    db = connect_db("db/webshop.db")
    class_name = params[:class_name]
    params = [class_name]
    is_valid(params)

    db.execute("INSERT INTO classes (class) VALUES (?)",class_name)

    redirect('/klasser')
end

# Displays page with students of a class
get('/klasser/:id') do
    db = connect_db("db/webshop.db")
    id = params[:id].to_i
    result = db.execute("SELECT * FROM students WHERE class_id = ?",id)
    p result
    class_name = db.execute("SELECT * FROM classes WHERE id = ?",id).first
    slim(:"items/show",locals:{result:result, class_id: id, class_name:class_name})
end

# Displays page to create new student
get('/klasser/:id/new') do
    id = params[:id].to_i
    slim(:"items/newstudent", locals:{id: id})
end

# Creates a new student and redirects to /klasser/id
#
# @param [String] student_name
# @param [Image] image
#
# @return student is created
post('/klasser/:id/new') do
    db = connect_db("db/webshop.db")
    student_name = params[:student_name]
    id = params[:id].to_i
    if params[:image] && params[:image][:filename]
        filename = params[:image][:filename]
        file = params[:image][:tempfile]
        path = "./public/img/#{filename}"
        File.open(path, 'wb') do |f|
            f.write(file.read)
        end
        path = "img/#{filename}"
    end
    param = [student_name, path]
    is_valid(param)
    db.execute("INSERT INTO students (name,image,class_id) VALUES (?,?,?)",student_name,path,id)
    redirect("/klasser/#{id}")
end

# Deletes an item and redirects to /items
#
# @param [Integer] id Id of the item
post('/klasser/:id/delete') do
    db = connect_db("db/webshop.db")
    id = params[:id].to_i
    class_id = session[:class_id]
    db.execute("DELETE FROM students WHERE id = ?", id)
    redirect("/klasser/#{class_id}")
end

# Displays interface to edit item
get('/klasser/:id/edit') do
    db = connect_db("db/webshop.db")
    id = params[:id].to_i
    result = db.execute("SELECT * FROM students WHERE id = ?", id).first
    result2 = db.execute("SELECT * FROM classes")
    slim(:"/items/edit", locals:{result:result,classes:result2})
end

# Updates the params of an item and redirects to /items
#
# @param [Integer] id Id of item
# @param [String] item_name
# @param [Integer] price
# @param [String] description
#
# @return item is updated
post('/klasser/:id/update') do
    db = connect_db("db/webshop.db")
    id = params[:id].to_i
    student_name = params[:student_name]
    #student_class = params[:student_class]

    params = [student_name,id]
    is_valid(params)

    db.execute("UPDATE students SET name = ? WHERE id = ?",student_name,id)
    redirect("/klasser/#{session[:class_id]}")
end

# Adds an item to the users cart and redirects to /items
#
# @param [Integer] id 
# @param [Integer] item_count
# 
# @return item is added to users cart
post('/klasser/:id/add_item') do
    db = connect_db("db/webshop.db")
    item_count = params[:item_count]
    id = params[:id].to_i

    result = db.execute("SELECT * FROM items WHERE id = ?", id).first  

    params = [item_count]
    is_valid(params)

    db.execute("INSERT INTO cart (user_id,item_id,item_count) VALUES (?,?,?)",session[:id],result["id"],item_count)
    redirect('/klasser')
end

# Displays the users students
get('/elever') do
    db = connect_db("db/webshop.db")
    result = db.execute("SELECT * FROM selected_classes WHERE user_id = ?",session[:id])
    i = 0
    result2 = []
    while i < result.length
        result2 << result[i]['class_id']
        i+=1
    end
    result3 = db.execute("SELECT * FROM students WHERE class_id IN (#{result2.join(",")})")
    slim(:"selected/index",locals:{students:result3})
end

# Displays a login page
get('/login') do
    slim(:"users/login")
end
  
# The user is logged in and redirected to /items
#
# @param [String] username
# @param [String] password
#
# @see Model#login
post('/login') do
    username = params[:username]
    password = params[:password]

    login(username, password)
end

# Displays a register page
get('/register') do
    slim(:"users/register")
end

# The user is registred and redirected to /login
#
# @param [String] username
# @param [String] password
# @param [String] password_confirm
# @param [String] adress
#
# @see Model#register
post('/register') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]

    register(username, password, password_confirm)
end

# The user is logged out and redirected to /
post('/logout') do
    session.clear
    redirect('/')
end