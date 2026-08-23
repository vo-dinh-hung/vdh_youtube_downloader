::[Bat To Exe Converter]
::
::YAwzoRdxOk+EWAnk
::fBw5plQjdG8=
::YAwzuBVtJxjWCl3EqQJgSA==
::ZR4luwNxJguZRRnk
::Yhs/ulQjdF+5
::cxAkpRVqdFKZSTk=
::cBs/ulQjdF+5
::ZR41oxFsdFKZSDk=
::eBoioBt6dFKZSDk=
::cRo6pxp7LAbNWATEpCI=
::egkzugNsPRvcWATEpCI=
::dAsiuh18IRvcCxnZtBJQ
::cRYluBh/LU+EWAnk
::YxY4rhs+aU+IeA==
::cxY6rQJ7JhzQF1fEqQJhZks0
::ZQ05rAF9IBncCkqN+0xwdVsFAlTi
::ZQ05rAF9IAHYFVzEqQIyPRJYSESMM2i1CKYT5O2b
::eg0/rx1wNQPfEVWB+kM9LVsJDAaXNWe+SLcd/Ig=
::fBEirQZwNQPfEVWB+kM9LVsJDAaXNWe+RrsT6+f1/OWLpy0=
::cRolqwZ3JBvQF1fEqQIxaAhZTQiOfH+1Cblc/Oe77OWJtEgPQKI5aoDWmrKHLOVd+lykYZltmH9Cnas=
::dhA7uBVwLU+EWFeD4Vs1JhJaRAyNPWW9RqEZ6+D14OaIpVR9
::YQ03rBFzNR3SWATE+kUlMR5aQg2MNGO1B7sbqPz+7OKJrUESU/tf
::dhAmsQZ3MwfNWATE900gMQldSwyWfDnqVONQqOb8+vOCrEMUWuo3d47V3fSaJeMb5EroepE0mDpblMdMHhJfdga4Lh0xumtQoGGBVw==
::ZQ0/vhVqMQ3MEVWAtB9wJhRARA2MOws=
::Zg8zqx1/OA3MEVWAtB9wJhRARA2MOws=
::dhA7pRFwIByZRRmK+1Y4IRVTLA==
::Zh4grVQjdCuDJFuR/U40Zh5MSWQ=
::YB416Ek+ZG8=
::
::
::978f952a14a936cc963da21a135fa983
pyinstaller --noconsole --onedir --contents-directory "." comments.py
if exist dist\comments (
    xcopy /y /e /i "C:\Users\Admin\AppData\Local\Programs\Python\Python311\Lib\site-packages\accessible_output3\lib" "dist\comments\accessible_output3\lib"
)