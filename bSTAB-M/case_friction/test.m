vd = 1.5; 
tspan = [0:1/50:20];
y0 = [2,2]; 

options = odeset('RelTol',1e-8);
[T0, Y0] = ode45(@(t,y) ode_friction(t, y, vd), tspan, y0, options);

idx = find(T0>13.5); 
T = T0(idx:end); 
Y = Y0(idx:end,:);

hold on;
plot(Y(:,1), Y(:,2)); hold on; 
plot(0.5, 0, '.', 'markerSize', 10); 