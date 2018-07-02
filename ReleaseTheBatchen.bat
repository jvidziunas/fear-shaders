FOR /r %%i in ( *.fx ) DO (
	fxc /T fx_2_0 /Gec /Fo "%%~pi%%~ni.fxo" "%%~fi"
)