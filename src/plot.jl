using Plots

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
	Grid(float(screen_width), float(screen_height),xdiff,ydiff, 144,90,p)
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

function plot(p::Winston.FramedPlot, saccades::Array{Saccade, 1};rows::Integer=5, cols::Integer=5,screen_width::Integer=1919, screen_height::Integer=1199)
	G = plot_grid(p, rows,cols;screen_width=screen_width, screen_height=screen_height)
	center_x = G.xmargin + 2*G.xdiff
	center_y = G.ymargin + 2*G.ydiff
	for saccade in saccades	
		x = [saccade.start_x, saccade.end_x]
		y = [saccade.start_y, saccade.end_y]
		Winston.add(p, Winston.Curve(x,y))
		Winston.add(p, Winston.Points([x[1]],[y[1]];symbolkind="circle"))
		Winston.add(p, Winston.Points([x[2]],[y[2]];symbolkind="filled circle"))
	end
	Winston.setattr(p, "xrange", (0, screen_width))
	Winston.setattr(p, "yrange", (0, screen_height))
	p
end

function plot(saccades::Array{Saccade,1};kvs...) 
	p = Winston.FramedPlot()
	plot(p, saccades;kvs...)
	p
end

