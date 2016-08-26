classdef BipedController < matlab.System & matlab.system.mixin.Propagates
    
    properties (Nontunable)
        Ts = 1e-3;
        env = Environment();
        ground_data = zeros(1, 5);
    end

    properties
        phase_rate = 1.5;
        target_dx = 0;
        step_offset = 0;
        energy_injection = 0;
    end
    
    
    properties (Access = private)
        cstate;
        cparams;
        cparams_default;
    end
    
    
    methods (Access = protected)
        function setupImpl(~)
        end
        
        
        function u = stepImpl(obj, X)
            
            obj.cparams_default.phase_rate = obj.phase_rate;
            obj.cparams_default.target_dx = obj.target_dx;
            obj.cparams_default.step_offset = obj.step_offset;
            obj.cparams_default.energy_injection = obj.energy_injection;
            
            obj.cparams.phase_rate = 0.99*obj.cparams.phase_rate + 0.01*obj.cparams_default.phase_rate;
            obj.cparams.target_dx = 0.99*obj.cparams.target_dx + 0.01*obj.cparams_default.target_dx;
            obj.cparams.step_offset = 0.99*obj.cparams.step_offset + 0.01*obj.cparams_default.step_offset;
            obj.cparams.energy_injection = 0.99*obj.cparams.energy_injection + 0.01*obj.cparams_default.energy_injection;
            
            step_time = 1 / obj.cparams.phase_rate / 2;
            
            Xpred = biped_sim(X, obj.cstate, obj.cparams, step_time, obj.Ts, obj.env, obj.ground_data);
            
            cparams_new = obj.cparams;
            cparams_new.phase_rate = cparams_new.phase_rate + randn() * 0.1;
            cparams_new.target_dx = cparams_new.target_dx + randn() * 0.3;
            cparams_new.step_offset = cparams_new.step_offset + randn() * 0.1;
            cparams_new.energy_injection = cparams_new.energy_injection + randn() * 100;
            
            
            
            Xpred_new = biped_sim(X, obj.cstate, cparams_new, step_time, obj.Ts, obj.env, obj.ground_data);
            
            if state_eval(Xpred_new) > state_eval(Xpred)
                obj.cparams = cparams_new;
            end

            [u, obj.cstate] = controller_step(X, obj.cstate, obj.cparams, obj.Ts);
            
        end
        
        
        function resetImpl(obj)
            obj.cstate = ControllerState();
            obj.cparams = ControllerParams();
            obj.cparams_default = ControllerParams();
        end
        
        
        function [sz1, sz2] = getOutputSizeImpl(~)
            sz1 = [1 1];
            sz2 = [1 2];
            
        end
        
        function [dt1, dt2] = getOutputDataTypeImpl(~)
            dt1 = 'control_bus';
            dt2 = 'double';
        end
        
        function [cm1, cm2] = isOutputComplexImpl(~)
            cm1 = false;
            cm2 = false;
        end
        
        function [fs1, fs2] = isOutputFixedSizeImpl(~)
            fs1 = true;
            fs2 = true;
        end
    end
    
    
    methods (Access = private)
        
    end
end


function v = state_eval(X)

y_right = X.body.y - X.right.l * cos(X.body.theta + X.right.theta);
y_left = X.body.y - X.left.l * cos(X.body.theta + X.left.theta);

v = min(min(y_right, y_left), -1e-3);

end
