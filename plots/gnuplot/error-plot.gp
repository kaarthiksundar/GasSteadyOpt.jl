set terminal cairolatex standalone pdf dashed transparent size 3, 3 \
header \
'\usepackage[scaled]{helvet}\usepackage[T1]{fontenc}\renewcommand\familydefault{\sfdefault}\usepackage{amssymb,bm}\usepackage{xcolor}\definecolor{blue}{RGB}{0,114,178}\definecolor{red}{RGB}{213,94,0}\definecolor{yellow}{RGB}{240,228,66} \definecolor{green}{RGB}{0,158,115}\newcommand{\hl}[1]{\setlength{\fboxsep}{0.75pt}\colorbox{white}{#1}}\usepackage[fontsize=9pt]{fontsize}'

output = 'error-resistor-box.tex'

# settings 
set grid ytics lc rgb "#bbbbbb" lw 0.5 lt 1
set grid xtics lc rgb "#bbbbbb" lw 0.5 lt 1
set mxtics 
set mytics

set datafile separator ','
set key autotitle columnhead
set style fill solid 0.7 border -1
set style boxplot outliers pointtype 7
set style data boxplot
set boxwidth 0.25
set pointsize 0.25
set style line 1 lc rgb 'grey80' lt 1 lw 2
set style line 2 lc rgb '#e52b50' lt 1 lw 2
set style line 3 lc rgb '#7e2f8e' lt 1 lw 2

set key bottom right
set key spacing 1.5
unset key
set logscale y
set ylabel 'Relative error (\%)'
# set xrange [1.0:9.0]
# set xtics   ('ideal' 2.0, 'simple CNGA' 5.0, 'full CNGA' 8.0)
set xrange [1.0:6.0]
set xtics   ('Ideal EoS' 2.0, 'CNGA EoS' 5.0)
set xlabel 'Equation of State (EoS)'
set output output
plot 'resistor_model_errors_4197.csv' using (2):1 ls 2 notitle, \
'' using (5):2 ls 2 notitle
# '' using (5):2 ls 2 notitle, \
# '' using (8):3 ls 2 notitle