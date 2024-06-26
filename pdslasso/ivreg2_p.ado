*! ivreg2_p 1.0.10 30jul2023
*! author mes
* 1.0.1: 25apr2002 original version
* 1.0.2: 28jun2005 version 8.2
* 1.0.3: 1Aug2006  complete rewrite plus fwl option
* 1.0.4: 26Jan2007 eliminated double reporting of #MVs
* 1.0.5: 2Feb2007  small fix to allow fwl of just _cons
* 1.0.6: 19Aug2007 replacement of "fwl" with "partial" in conjuction with new ivreg2 syntax
* 1.0.7: 4Feb2010  version check update
* 1.0.8: 30Jan2011 re-introduced stdp option (hadn't been supported after fwl/partial)
*                  and added labelling of created residual variable
* 1.0.9: 25Jan2015 Rewrite to accommodate new ivreg2 with legacy support;
*                  passes control to matching ivreg2x_p predict program.
* 1.0.10:30Jul2023 Change version of ivreg211_p to 11.2, tsrevar->fvrevar to handle FVs (cfb0)

program define ivreg2_p

* Minimum of version 8 required (earliest ivreg2 is ivreg28)
	version 8

* If estimation used current ivreg2, pass control to ivreg211 subroutine below.
* If estimation used legacy ivreg2x, pass control to earlier version.

	if "`e(ivreg2cmd)'"=="ivreg2" {
		ivreg211_p `0'
	}
	else if "`e(ivreg2cmd)'"=="ivreg210" {
		ivreg210_p `0'
	}
	else if "`e(ivreg2cmd)'"=="ivreg29" {
		ivreg29_p `0'
	}
	else if "`e(ivreg2cmd)'"=="ivreg28" {
		ivreg28_p `0'
	}
	else {
di as err "Error - ivreg2 estimation missing e(ivreg2cmd) macro"
		exit 601
	}

end


* Main/current predict program: upgrade to v11.2 for FV handling
program define ivreg211_p
//	version 8.2
	version 11.2
	syntax newvarname [if] [in] , [XB Residuals stdp]
	marksample touse, novarlist

* Check ivreg2 version is compatible.
* fwl becomes partial starting in ivreg2 02.2.07
		local vernum "`e(version)'"
		if ("`vernum'" < "03.0.00") | ("`vernum'" > "09.9.99") {
di as err "Error: incompatible versions of ivreg2 and ivreg2_p."
di as err "Currently installed version of ivreg2 is `vernum'"
di as err "To update, from within Stata type " _c
di in smcl "{stata ssc install ivreg2, replace :ssc install ivreg2, replace}"
			exit 601
		}

	local type "`xb'`residuals'`stdp'"

	if "`type'"=="" {
		local type "xb"
di in gr "(option xb assumed; fitted values)"
	}

* e(partialcons) now always exists and is 1 or 0
	if e(partial_ct) {
* partial partial-out block
		if "`type'" == "residuals" {
	
			tempvar esample
			tempname ivres
			gen byte `esample' = e(sample)

* Need to strip out time series operators *** and FVs ***
			local lhs "`e(depvar)'"
//			tsrevar `lhs', substitute
			fvrevar `lhs', substitute
			local lhs_t "`r(varlist)'"

			local rhs : colnames(e(b))
//			tsrevar `rhs', substitute
			fvrevar `rhs', substitute
			local rhs_t "`r(varlist)'"

			if "`e(partial1)'" != "" {
				local partial "`e(partial1)'"
			}
			else {
				local partial "`e(partial)'"
			}
//			tsrevar `partial', substitute
			fvrevar `partial', substitute
			local partial_t "`r(varlist)'"

			if ~e(partialcons) {
				local noconstant "noconstant"
			}
	
			local allvars "`lhs_t' `rhs_t'"
* Partial-out block.  Uses estimatation sample to get coeffs, markout sample for predict
			_estimates hold `ivres', restore
			foreach var of local allvars {
				tempname `var'_partial
				qui regress `var' `partial' if `esample', `noconstant'
				qui predict double ``var'_partial' if `touse', resid
				local allvars_partial "`allvars_partial' ``var'_partial'"
			}
			_estimates unhold `ivres'

			tokenize `allvars_partial'
			local lhs_partial "`1'"
			mac shift
			local rhs_partial "`*'"

			tempname b
			mat `b'=e(b)
			mat colnames `b' = `rhs_partial'
* Use forcezero?
			tempvar xb
			mat score double `xb' = `b' if `touse'
			gen `typlist' `varlist' = `lhs_partial' - `xb'
			label var `varlist' "Residuals"
		}
		else {
di in red "Option `type' not supported with -partial- option"
			error 198
		}
	}
	else if "`type'" == "residuals" {
		tempname lhs lhs_t xb
		local lhs "`e(depvar)'"
//		tsrevar `lhs', substitute
		fvrevar `lhs', substitute
		local lhs_t "`r(varlist)'"
		qui _predict `typlist' `xb' if `touse'
		gen `typlist' `varlist'=`lhs_t'-`xb'
		label var `varlist' "Residuals"
	}
* Must be either xb or stdp
	else {
		_predict `typlist' `varlist' if `touse', `type'
	}

end
