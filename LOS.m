function X_d = LOS(x, y, x1, y1, x2, y2, K_p)

[y_e, pi_p] = ctrackW(x2, y2, x1, y1, x, y);

X_d = pi_p - atan(K_p*y_e);

