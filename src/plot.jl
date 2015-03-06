import Winston
import Winston.plot

type Grid
	screen_width::Float64
	screen_height::Float64
	xdiff::Float64
	ydiff::Float64
	xmargin::Float64
	ymargin::Float64
	p::Winston.FramedPlot
end

function plot_grid(p::Winston.FramedPlot, rows::Int64, cols::Int64;screen_width::Int64=1440, screen_height::Int64=900)
	xdiff = (screen_width-2*144.0)/cols
	ydiff = (screen_height-2*90.0)/rows

	for i in 0:5
		Winston.add(p, Winston.Curve([144,screen_width-144],[90+i*ydiff,90+i*ydiff]))
	end
	for i in 0:5
		Winston.add(p, Winston.Curve([144+i*xdiff, 144+i*xdiff], [90, screen_height-90]))
	end
end

function plot(p::Winston.FramedPlot, fixations::Array{EyeEvent,1},rows::Int64, cols::Int64,screen_width::Int64, screen_height::Int64)
	plot_grid(p, rows,cols;screen_width=screen_width, screen_height=screen_height)
	x = zeros(length(fixations))
	y = zeros(x)
	for (i,ee) in enumerate(fixations)
		x[i],y[i] = ee.x, ee.y
	end
	idx = (x.>0)&(x.<screen_width)&(y.>0)&(y.<screen_height)
	Winston.add(p, Winston.Points(x[idx],y[idx];symbolkind="circle"))	
	p
end

function plot(fixations::Array{EyeEvent,1},rows::Int64, cols::Int64,screen_width::Int64, screen_height::Int64)
	p = Winston.FramedPlot()
	plot(p, fixations, rows, cols, screen_width, screen_height)
	p
end

plot(fixations::Array{EyeEvent,1}) = plot(fixations, 5,5, 1440, 900)

