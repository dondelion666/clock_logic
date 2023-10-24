g=grid.connect()
m=midi.connect()

buttons_held=0
selected_button=0
button_stage=0 --COUNT BUTTON PRESSES WHEN BUTTON HELD
button_count=0
function_button=0

buttons={}

led_clocks={} --STORE CLOCKS


operators={"clock","and","or","xor","not"}


function init()
  clock.run(grid_redraw_clock)
  
  for i=1,128 do
    
    buttons[i]={
      type=0,
      state=0,
      prev_state=0,
      inputs={},
      note=0,
      outputs={},
      time=0,
      }
    
  end  
  
  --GET NORNS CLOCK AND ASSIGN TO BUTTON 17
  buttons[17].type=7
  buttons[17].inputs[1]=17
  led_clocks[17]=clock.run(blonk)
  
end

function grid_redraw_clock()
  while true do
    clock.sleep(1/30)
    if grid_dirty then
      grid_redraw()
      grid_dirty=false
    end
  end
end

--SYNCD NORNS CLOCK
function blonk()
  while true do
    clock.sync(1)
    buttons[17].prev_state=buttons[17].state
    buttons[17].state=flip(buttons[17].state)
    
    if get_change(buttons[17].prev_state,buttons[17].state)==1 then
          play_note(17)
    end
    
  grid_dirty=true
  end
end

--UNSYNCD CLOCK
function blink(clock_id)
  while true do
    clock.sleep(buttons[clock_id].time)
    
    --update each button output
    for k,v in pairs(buttons[clock_id].outputs) do
      
      --store prev state
      buttons[v].prev_state=buttons[v].state
      
      --if button is a clock flip its state
      if buttons[v].type==1 then
        buttons[v].state=flip(buttons[v].state)
      end
      
      --assign inputs to local variables
      if next(buttons[v].inputs)~=nil then
        local in1=0
        local in2=0
        if #buttons[v].inputs==1 then
          in1=buttons[buttons[v].inputs[1]].state
        elseif #buttons[v].inputs==2 then
          in1=buttons[buttons[v].inputs[1]].state
          in2=buttons[buttons[v].inputs[2]].state
        end
        
        --bitwise operators
        if buttons[v].type==2 then
          buttons[v].state=in1 & in2
        elseif buttons[v].type==3 then 
          buttons[v].state=in1 | in2
        elseif buttons[v].type==4 then 
          buttons[v].state=in1 ~ in2
        elseif buttons[v].type==5 then
            --print("in1 "..in1)
            buttons[v].state=flip(in1)
        --elseif buttons[v].type==6 then
          --buttons[v].inputs[3]=(buttons[v].inputs[3]+1)%(buttons[v].inputs[2]-16)
          --print("mod "..buttons[v].inputs[2])
        end 
        
      end
    
    --play note if state changed from 0 to 1
    if get_change(buttons[v].prev_state,buttons[v].state)==1 then
          play_note(v)
    end
      
    end
    
    grid_dirty=true
    
  end
end

function flip(x)
  return (x+1)%2
end

function get_button_number(x,y)
  return ((y-1)*16)+x
end

function get_row_col(x)
  local row=(x%16)+1
  local col=x//16
  return row,col
end

function get_clock(x)
  --for each input
end

function get_change(prev,state)
  local x=0
  
  if prev>state then
    x=-1
  elseif state>prev then
    x=1
  end
  
  return x
end

function play_note(x)
  --print("play "..x)
  m:note_on(buttons[x].note,100,1)
end

function remove_dup(t)
  local hash = {}
  local res = {}

  for _,v in ipairs(t) do
     if (not hash[v]) then
         res[#res+1] = v -- you could print here instead of saving to result table if you wanted
         hash[v] = true
    end
  end
  
  return res
end

function reset_button(x)
  buttons[x]={
      type=0,
      state=0,
      prev_state=0,
      inputs={},
      note=0,
      outputs={},
      time=0,
      }
end

function add_clock(x)
  buttons[x].time=math.random(100)/100
  table.insert(buttons[x].inputs,x)
  table.insert(buttons[x].outputs,x)
  led_clocks[x]=clock.run(blink,x)
end

function add_op(x,y,s)
  local in1=get_button_number(x,y)
    --ADD INPUTS
    table.insert(buttons[s].inputs,in1)
    
    for k,v in pairs (buttons[in1].inputs) do
          table.insert(buttons[v].outputs,s)
          buttons[v].outputs=remove_dup(buttons[v].outputs)
    end
end

function g.key(x,y,z)
  
  --GET FUNCTION BUTTON
  if z==1 and y==8 then
    function_button=x
  elseif z==0 and y==8 then
    function_button=0
  end
  
  --GET NUMBER OF BUTTONS HELD
  if z==1 and buttons_held==0 then
    buttons_held=1
  elseif z==1 and buttons_held>0 then
    buttons_held=buttons_held+1
  elseif z==0 and buttons_held>0 then
    buttons_held=buttons_held-1
  end 
  
  --GET BUTTON STAGE
  if buttons_held>1 then
    if z==1 then
      button_stage=button_stage+1
      --print("stage "..button_stage)
    end
  elseif buttons_held==0 then
    button_stage=0
    --print("stage "..button_stage)
  end
  
  --GET SELECTED BUTTON
  if z==1 and buttons_held==1 then
    selected_button=get_button_number(x,y)
    button_count=button_count+1
    buttons[selected_button].note=35+button_count
    --print(selected_button)
  elseif z==0 and buttons_held==0 then
    selected_button=0
    --print("button up")
  end
  
  --GET FUNCTION X=1 Y=1 IS CLOCK, X=2 Y=1 IS AND, X=3 AND Y=1 IS OR, X=4 AND Y=1 IS XOR
  if z==1 and buttons_held==2 and y==1 then
    buttons[selected_button].type=x
    
    --if clock set time, set input to button to feed thru to descendents
    if x==1 then
      add_clock(selected_button)
    end
  end
  
  if button_stage>1 and z==1 then
    add_op(x,y,selected_button)
  end
 
  if function_button==1 and selected_button>0 then
    reset_button(selected_button)
  end
  
 
end


function grid_redraw()
  g:all(0)
  
  for i=1,16 do
    for j=1,8 do
      local k=get_button_number(i,j)
      g:led(i,j,buttons[k].state*15)
    end
  end
  
  g:refresh()
end
