/********************************************************************************
* PROJECTO: Task 1 Labor Market Outcomes of Graduates  
* AUTHOR: Lucia Gomez Llactahuamani                         
* YEAR:		2020
*********************************************************************************
	
*** Outline:
	0. Set initial configurations and globals
	1. Clean datasets
	2. Merge and append datasets
	3. Construction of key variables
	4. Rank of universities
	5. Figures

*********************************************************************************
*	PART 0: Set initial configurations and globals
********************************************************************************/

*** 0.1 Install required packages

	set type double
	set more off
	
*** 0.2 Setting up folders

// General

	global project 		"F:\RESEARCH\OPPORTUNITIES\RA\TASK1"
	global data 		"${project}\data"
	global outputs 		"${project}\outputs"
	
// Data

	global data_2014 		"${data}\enaho14"
	global data_2015 		"${data}\enaho15"
	global data_2016 		"${data}\enaho16"
	global data_2017 		"${data}\enaho17"
	global data_2018 		"${data}\enaho18"

*********************************************************************************
*	PART 1: Clean datasets
*********************************************************************************

// Clean Modulo 100: Caracteristicas de la vivienda y el hogar 
	
	forval n=2014/2018 {
	
	* Load in Modulo 100
	use "${data_`n'}\enaho01-`n'-100.dta", clear  
	
	* Keep relevant variables
	keep 	conglome vivienda hogar								/// Keep variables needed for merging to other datasets
			p104 p105a											// Keep the variables needed for the analysis	
	
	* Store cleaned data
	save "${outputs}\enaho01-`n'_100_clean.dta", replace
	}
	
// Clean Modulo 200: Caracteristicas de los miembros del hogar
	
	forval n=2014/2018 {
	
	* Load in Modulo 200
	use "${data_`n'}\enaho01-`n'-200.dta", clear  
	
	* Keep relevant variables
	keep 	conglome vivienda hogar codperso					/// Keep variables needed for merging to other datasets
			p208a 												// Keep the variables needed for the analysis	
	
	* Store cleaned data
	save "${outputs}\enaho01-`n'_200_clean.dta", replace
	}

	// Clean Modulo 300: Educación
	
	forval n=2014/2018 {
	
	* Load in Modulo 300
	use "${data_`n'}\enaho01a-`n'-300.dta", clear  
	
	* Keep relevant variables
	keep 	conglome vivienda hogar codperso					///  Keep variables needed for merging to other datasets
			p301* 												// Keep the variables of interest
	
	* Store cleaned data
	save "${outputs}\enaho01-`n'_300_clean.dta", replace
	}

// Clean Modulo 500: Empleo e ingresos
	
	forval n=2014/2018 {
	
	* Load in Modulo 500
	use "${data_`n'}\enaho01a-`n'-500.dta", clear  
	
	* Keep relevant variables
	keep 	conglome vivienda hogar codperso					  ///  Keep variables needed for merging to other datasets
			i524a1 d529t i530a d536 i538a1 d540t i541a d543 d544t // Keep the variables of interest	
	
	* Store cleaned data
	save "${outputs}\enaho01-`n'_500_clean.dta", replace
	}
	
*********************************************************************************
*	PART 1: Merge and append datasets
*********************************************************************************
			
	* Merge datasets

	forval n=2014/2018 {
	
	* Load in household level module
	use "${outputs}\enaho01-`n'_100_clean.dta", clear  	//  Load in cleaned Modulo 100 
	
	* Merge to individual level modules
	merge 1:m conglome vivienda hogar          using "${outputs}\enaho01-`n'_200_clean.dta", gen(_merge200)		// Merge cleaned Modulo 200 
	merge 1:1 conglome vivienda hogar codperso using "${outputs}\enaho01-`n'_300_clean.dta", gen(_merge300) 		// Merge cleaned Modulo 300
	merge 1:1 conglome vivienda hogar codperso using "${outputs}\enaho01-`n'_500_clean.dta", gen(_merge500)		// Merge cleaned Modulo 500
	keep if _merge500==3  		// Keep all the observations of earlier datasets which merge to Modulo 500
	drop 	_merge* 
	gen 	year=`n'		  	// Generate a variable to identify the year the observations where collected 
	order 	year
	
	* Store dataset
	save "${outputs}\enaho01-`n'_clean.dta", replace
	}
		
	* Append datasets
	
	use			  "${outputs}\enaho01-2014_clean.dta", clear
	append using  "${outputs}\enaho01-2015_clean.dta"
	append using  "${outputs}\enaho01-2016_clean.dta"
	append using  "${outputs}\enaho01-2017_clean.dta"
	append using  "${outputs}\enaho01-2018_clean.dta"
	save 		  "${outputs}\enaho01-2014-2018_clean.dta", replace	// 466,208 observations
	
*********************************************************************************
*	PART 3: Construction of key variables
*********************************************************************************
	
	use "${outputs}\enaho01-2014-2018_clean.dta", clear
		
	* Keep the population target of this study: University graduates 
		rename 	p301a nivel_educ	
		label 	variable nivel_educ "Level of education"
		tab 	nivel_educ				   // Tab education level
		keep if nivel_educ == 10 
		
	*3.1 Income 
		egen 	income 	 =   rowtotal(i524a1 	/// Ingreso en la ocupación principal por trabajo dependiente
									  d529t  	/// Valor estimado del pago en especie en su ocupación principal
									  i530a 	/// Ingreso en la ocupación principal por trabajo independiente
									  d536 		/// Valor del autoconsumo en la ocupación principal
									  i538a1 	///	Ingreso en la ocupación secundaria por trabajo dependiente
									  d540t 	/// Valor estimado del pago en especie en su ocupación secundaria
									  i541a 	///	Ingreso en la ocupación secundaria por trabajo independiente
									  d543 		/// Valor del autoconsumo en la ocupación secundaria 
									  d544t)	//  Ingresos extraordinarios por trabajo dependiente
										  
		gen  	log_income = log(income+1)
		label 	variable log_income "Income in logharithms"
		
	*3.2 University
		rename 	p301b1 cod_university
		label 	variable cod_university "University ID"
		drop 	if cod_university==0
		
	*3.2 Major
		rename 	p301a1 cod_major 
		label 	variable cod_major "Major ID"
		drop 	if cod_major==999999 
		
	*3.3 Years since graduation
	   * I build this variable taking the difference between the age of graduates and 25 (average year where the people graduate and start to work)
		rename 	p208a age
		gen 	years_grad = .
		replace years_grad = 0 if age <= 24 			// If the age of graduates is less than 25, replace the variable "years since graduation" with 0   
		replace years_grad = age - 25 if age >=25		
		label   variable years_grad "Years since graduation"
		
	*3.4 Rooms in apartment/house
		rename 	p104 rooms 
		label 	variable rooms "Number of rooms in apartment or house"
	
	*3.5 Homeownership status
		gen 	home = .
		replace home = 1 if p105a == 1 					// variable home equal to 1 if home is rented
		replace home = 2 if p105a >= 2 & p105a <= 4 	// variable home equal to 2 if home is 
		replace home = 3 if p105a >= 5
		label 	define home 1 "Rented" 2 "Own" 3 "Other"
		label 	value  home home
		label 	variable home "homeownership status"
	
	* Keep variables of interest
		keep 	year conglome vivienda hogar			/// Identification variables
				income log_income 						/// Income							
				cod_university							/// University
				cod_major								/// Major
				years_grad								/// Years since graduation
				rooms									/// Rooms in apartment/house
				home									// Homwownership status
	
	* Drop missings into variables of interest
	
 foreach var of varlist income log_income cod_university cod_major years_grad rooms home{
	drop if missing(`var')
}				

	* Numer of observations per year
	/*
	
       year |      Freq.     Percent        Cum.
------------+-----------------------------------
       2014 |      5,411       17.60       17.60
       2015 |      5,728       18.63       36.23
       2016 |      6,618       21.53       57.76
       2017 |      6,213       20.21       77.97
       2018 |      6,772       22.03      100.00
------------+-----------------------------------
      Total |     30,742      100.00                	
	*/
	
	* Save data with key variables
	save "${outputs}\enaho01-2014-2018_key.dta", replace	
	
*********************************************************************************
*	PART 4: Rank of universities 
*********************************************************************************
	
	use "${outputs}\enaho01-2014-2018_key.dta", clear

	*Regression
	reghdfe log_income years_grad rooms i.home year , abs(cod_university cod_major, save) vce(robust)
	
	*Generating the ranking
	bysort cod_university: egen rank_university = rank(__hdfe1__)
	
	*Evaluating how different universities affect the labor market outcomes of graduates.
	reg log_income rank_university years_grad rooms i.home year i.cod_major, vce(robust) 
	
	
*********************************************************************************
*	PART 5: Figures
*********************************************************************************
	
