
% Parameters
d = 1.5*pi/180;
%d=0;
delta_max=30;
e_max=15;
zeta_phi=0.707;
zeta_chi=0.9;
a_phi_1=2.87;
a_phi_2=-0.65;
g=9.81;
V_g=580;


%Roll 
kp_phi=delta_max/e_max*sign(a_phi_2); %u_max/e_max bc saturation limits 
ki_phi=0; %because don't want intergal part 
omega_n_phi=sqrt(a_phi_2*kp_phi);
kd_phi=(2*zeta_phi*omega_n_phi-a_phi_1)/a_phi_2;

%Course 
omega_n_chi=1/15*omega_n_phi; 
kp_chi=2*zeta_chi*omega_n_chi*V_g/g;
ki_chi=omega_n_chi^2*V_g/g;  
%ki_chi = 0;

%tf_root_analysis_k_i_phi = tf(-a_phi_2,[1 (a_phi_1 + a_phi_2*kd_phi) kp_phi*a_phi_2 ki_phi*a_phi_2]);
              
% Plot rlocus
%rlocus(tf_root_analysis_k_i_phi);


%sim('autopilot.slx')

%matrices
A =  [-0.322, 0.052, 0.028, -1.12, 0.002;
             0, 0, 1, -0.001, 0;
             -10.6, 0, -2.87, 0.46, -0.65;
             6.87, 0, -0.04, -0.32, -0.02;
             0, 0, 0, 0, -7.5];
B = [0; 0; 0; 0; 7.5;];
C = [1, 0,0,0,0;
     0,1,0,0,0;
     0,0,1,0,0;
     0,0,0,1,0];
 D = [0; 0; 0; 0;];

sim_time = 500;

out = sim('autopilot', sim_time);

figure('rend','painters','pos',[10 10 750 400])
hold on;
plot(out.Chi, "b");
plot(out.chi_control, "r");
plot(out.delta_control, "m--")
title("Task 2g, controller performance, simplified model");
xlabel("time [s]");
ylabel("angle [deg]");
grid on;
hold off;
legend({"\chi [deg]", "\chi_c [deg]", "\delta_a [deg]"}, "Location", "northeast");