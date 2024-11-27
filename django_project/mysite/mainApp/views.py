from django.shortcuts import render

def index(request):
    data = {
        'title': 'Главная страница',
        'values': ['Some', 'Hello', '123'],
        'obj': {
            'car': 'Mers',
            'age': 18,
            'hobby': 'Football'
        }
    }
    return render(request, 'mainApp/schedule.html', data)

def about(request):
    return render(request, 'mainApp/about.html')

