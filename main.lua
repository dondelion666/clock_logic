g=grid.connect()
m=midi.connect()

buttons_held=0
selected_button=0
button_stage=0 --COUNT BUTTON PRESSES WHEN BUTTON HELD
button_count=0

buttons={}

led_clocks={} --STORE CLOCKS
clocks={} --STORE CLOCK INFO

types={"clock","and","or","xor","not"}


function init()
  clock.run(grid_redraw_clock)
  
  for i=1,128 do
    
    buttons[i]={
      type=0,
      state=0,
      prev_state=0,
      inputs={},
      note=0,
      }
    
    clocks[i]={
      time=0,
      outputs={},
      }
  end
  
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

function blink(clock_id)
  while true do
    clock.sleep(clocks[clock_id].time)
    
    for k,v in pairs(clocks[clock_id].outputs) do
      
      buttons[v].prev_state=buttons[v].state
      
      if buttons[v].type==1 then
        --if button is a clock flip its state
        --print("clock "..v)
        buttons[v].state=flip(buttons[v].state)
      end
      
      
      
      if next(buttons[v].inputs)~=nil then
        if #buttons[v].inputs==2 then
          local in1=buttons[buttons[v].inputs[1]].state
          local in2=buttons[buttons[v].inputs[2]].state
      
          if buttons[v].type==2 then
            buttons[v].state=in1 & in2
          elseif buttons[v].type==3 then 
            buttons[v].state=in1 | in2
          elseif buttons[v].type==4 then 
            buttons[v].state=in1 ~ in2
          --elseif buttons[v].type==6 then
            --buttons[v].inputs[3]=(buttons[v].inputs[3]+1)%(buttons[v].inputs[2]-16)
            --print("mod "..buttons[v].inputs[2])
          end
        elseif #buttons[v].inputs==1 then
          local in1=buttons[buttons[v].inputs[1]].state
          if buttons[v].type==5 then
            --print("in1 "..in1)
            buttons[v].state=flip(in1)
          end
        end 
        
      end
    
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
  print("play "..x)
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

function g.key(x,y,z)
  
  
  
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
  end  
  
  --SELECTED BUTTON OFF
  if z==0 and buttons_held==0 then
    selected_button=0
    --print("button up")
  end
  
  --GET FUNCTION X=1 Y=1 IS CLOCK, X=2 Y=1 IS AND, X=3 AND Y=1 IS OR, X=4 AND Y=1 IS XOR
  if z==1 and buttons_held==2 and y==1 then
    buttons[selected_button].type=x
    if x==1 then
      clocks[selected_button].time=math.random(100)/100
      
      table.insert(buttons[selected_button].inputs,selected_button)
      table.insert(clocks[selected_button].outputs,selected_button)
      led_clocks[selected_button]=clock.run(blink,selected_button)
      --print(types[buttons[selected_button].type])
      --tab.print(clocks[selected_button].outputs)
    end
  end
  
  if button_stage>1 and z==1 then
    local in1=get_button_number(x,y)
    --ADD INPUTS
    table.insert(buttons[selected_button].inputs,in1)
    --table.insert(buttons[selected_button].triggers,buttons[in1].triggers)
    for k,v in pairs (buttons[in1].inputs) do
          table.insert(clocks[v].outputs,selected_button)
          clocks[v].outputs=remove_dup(clocks[v].outputs)
          --print("loop - k "..k.." v "..v)
    end
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
