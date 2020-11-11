function [X_d, y_int_dot] = ILOS(x, y, x1, y1, x2, y2, K_p, Bc, y_int, K_i)
%Bc = Bc*(pi/180);
[y_e, pi_p] = ctrackW(x2, y2, x1, y1, x, y);
y_int_dot = y_e * (1/K_p)/(1/(K_p^2+(y_e+K_i/K_p*y_int)^2));
X_d = pi_p - atan(K_p*y_e+K_i*y_int);


