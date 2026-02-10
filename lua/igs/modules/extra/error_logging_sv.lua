hook.Add("IGS.OnApiError", "LogError", function(sMethod, error_uid, tParams)
	tParams = tParams or {}
	if error_uid == "db_not_connected" then
		IGS.print(Color(255,0,0), "MySQL He gocTynen. nPOBEPbTE HACTPOuKu u COEguHeHue")
	end

	local sparams = "\n"
	for k,v in pairs(tParams) do
		sparams = sparams .. ("\t%s = %s\n"):format(k,v)
	end

	local split = string.rep("-",50)
	local err_log =
		os.date("%Y-%m-%d %H:%M\n") ..
		split ..
		"\nMethod: " .. sMethod ..
		"\nError: "  .. error_uid ..
		"\nParams: " .. sparams ..
		split .. "\n\n\n"

	file.Append("igs_errors.txt",err_log)
	IGS.dprint(err_log)
end)
