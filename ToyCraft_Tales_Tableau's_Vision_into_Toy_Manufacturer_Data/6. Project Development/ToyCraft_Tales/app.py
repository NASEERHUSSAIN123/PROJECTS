from flask import Flask, render_template

app = Flask(__name__)

@app.route('/')
def home():
    links = {
        "dashboard": "https://public.tableau.com/views/Dashboard_17712395449780/Dashboard?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link",
        "story": "https://public.tableau.com/views/Story_17712399484350/Story?:language=en-US&:sid=&:redirect=auth&:display_count=n&:origin=viz_share_link"
    }
    return render_template('index.html', urls=links)

if __name__ == '__main__':
    app.run(debug=True)