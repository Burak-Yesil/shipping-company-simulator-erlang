-module(shipping).
-compile(export_all).
-include_lib("./shipping.hrl").

%Burak Yesil 
%I pledge my honor that I have abided by the Stevens Honor System.

get_ship(Shipping_State, Ship_ID) ->
    Result = lists:keyfind(Ship_ID, #ship.id, Shipping_State#shipping_state.ships),
    case Result of
        false -> error;
        _ -> Result
    end.


get_container(Shipping_State, Container_ID) ->
    Result = lists:keyfind(Container_ID, #container.id, Shipping_State#shipping_state.containers),
    case Result of
        false -> error;
        _ -> Result
    end.

get_port(Shipping_State, Port_ID) ->
    Result = lists:keyfind(Port_ID, #port.id, Shipping_State#shipping_state.ports),
    case Result of
        false -> error;
        _ -> Result
    end.

get_occupied_docks(Shipping_State, Port_ID) ->
    % Example (1, 'A', 3) -> if port 1, dock 'A' contains ship 3
    %filtering for only docks located in port ID
    PortIdDocks = lists:filter(fun ({Port, _Dock, _Ship}) -> Port == Port_ID end, Shipping_State#shipping_state.ship_locations), 
    %getting all of the occupied docks at port ID
    OccupiedDocks = lists:map(fun ({_Port, Dock, _Ship}) -> Dock end, PortIdDocks),
    %return occupied docks
    OccupiedDocks.

get_ship_location(Shipping_State, Ship_ID) ->
    % H = lists:keyfind(Ship_ID, 3, Shipping_State#shipping_state.ship_locations), %3 because the ship ID is the third element in the tuple
    % %[H|_] = lists:filter(fun ({_Port, _Dock, Ship}) -> Ship == Ship_ID end, Shipping_State#shipping_state.ship_locations), 
    % case H of %ASK PAT ABOUT ERROR CASE -> he said to use keyfind instead of filter
    %     {Port, Dock, _Ship} -> {Port, Dock};
    %     _ -> error
    % end.  %%----------FIX THIS-----------
    {_, _, _, _, ShipLocations, _, _} = Shipping_State,
	case ShipLocations of
	  [] -> error;
	  [{Port, Dock, Ship} | T] -> 
                        case Ship of
						   Ship_ID -> {Port, Dock};
						   _ ->
                            {shipping_state, Ships, Containers, Ports, _, ShipInventory, PortInventory} = Shipping_State, 
                            get_ship_location({shipping_state, Ships, Containers, Ports, T, ShipInventory, PortInventory}, Ship_ID)
						 end
	end.


get_container_weight(_Shipping_State, []) -> %%Recursive base case
    0;

get_container_weight(Shipping_State, Container_IDs) ->
    %ATTEMPT 1:
    [H|T] = Container_IDs,
    CurrentContainer = get_container(Shipping_State, H),
    case CurrentContainer of
        false -> error;
        _ -> CurrentContainer#container.weight + get_container_weight(Shipping_State, T)
    end.



get_ship_weight(Shipping_State, Ship_ID) ->
    case maps:find(Ship_ID, Shipping_State#shipping_state.ship_inventory) of 
        {ok, ContainersList} -> get_container_weight(Shipping_State ,ContainersList);
        _ -> error
    end.   


total_length_greater_than_cap(Container_IDs_Length, Curr_List_Length, Cap_Size) -> 
    %Helper Function:
    %Returns boolean of whether or not containers ids length and curr list length are greater than the cap
    Container_IDs_Length + Curr_List_Length < Cap_Size.

in_list(M,L) -> %Same as built in member function but just wanted to get some practice in
    case L of
    [] -> false;        
    [H|T] ->
        if 
        H==M ->
            true;
        true -> 
            in_list(M,T)
        end
    end. 



load_ship(Shipping_State, Ship_ID, Container_IDs) ->   
    %ATTEMPT 1:
    % %STEP 1: Checking that the size of the list isn't greater than the ship capacity:
    % SizeOfList = lists:foldl(fun(_X, Sum) -> 1 + Sum end, 0, Container_IDs), %Get the list of containers 
    % CurrentShip = get_ship(Shipping_State, Ship_ID),
    
    % case CurrentShip of 
    %     {_ID, _Name, ShipCapacity} -> if  %checking if Ship exists 
    %                                 SizeOfList > ShipCapacity -> error %if list size is greater than ship capacity, throw error
    %                                 end;
    %     _ -> error %if ship doesn't exists, throw error  
    % end.
    %ATTEMPT 2:
    ShipLocation = get_ship_location(Shipping_State, Ship_ID), %Getting current ships location -> {Port_ID, Dock_ID}
    
    case ShipLocation of
    {Port, _Dock} -> 
        {ship, _ID, _Name, Cap} = get_ship(Shipping_State, Ship_ID), %If the Ship exists, call getShip and unpack the result into {ship, _ID, _Name, Cap}
        {_, _, _, _, _, ShipInventory, PortInventory} = Shipping_State, %Tuple unpacking the Shipping_State
        {_OKX, ShipInventoryList} = maps:find(Ship_ID, ShipInventory), %Find ship inventory inside of ShipInventory map/dictionary/record 
        LessThanCapSize = total_length_greater_than_cap(length(Container_IDs), length(ShipInventoryList), Cap),
        case LessThanCapSize of
            false -> error;
            true ->
                {_OKY, L} = maps:find(Port, PortInventory), %Checks if specified port is in the port inventory
                SubListOrNot = lists:all(fun (X) -> in_list(X, L) end, Container_IDs), %Later realized this is similar to is_sublist function already given lol
                case SubListOrNot of
                    false -> error;
                    true -> Func = fun(X, L) -> 
                        case in_list(X, Container_IDs) of %SIDE NOTE: could have also use member built in function but wanted to practice recursion
                            true -> L;
                            false -> [X | L] 
                        end 
                end,
            ListOfPorts = lists:foldl(Func, [], L),
            {shipping_state, Ships, Containers, Ports, ShipLocations, _, _} = Shipping_State, %Unpacking the default values
            %Returning new and updated shipping_state
            {ok, {shipping_state, Ships, Containers, Ports, ShipLocations, 
            ShipInventory#{Ship_ID => ShipInventoryList ++ Container_IDs}, %Updated ship inventory
            PortInventory#{Port => ListOfPorts}}} %Updated port inventory
            end;
            error -> error %If the Ship ID doesn't exist throw an error
        end
    end.  
        
    


unload_ship_all(Shipping_State, Ship_ID) ->
    ShipLocation = get_ship_location(Shipping_State, Ship_ID),
    case ShipLocation of
        {Port, _} ->  
            {_, _, _, _, _, ShipInventory, PortInventory} = Shipping_State,  %Unpacking Shipping_state into individual variables
            {_OKX, ShipInventoryList} = maps:find(Ship_ID, ShipInventory),
            {_OKY, PortInventoryList} = maps:find(Port, PortInventory),
            PortResult = get_port(Shipping_State, Port),
            {port, _, _, _, Cap} = PortResult,
            LessThanCapSize = total_length_greater_than_cap(length(PortInventoryList), length(ShipInventoryList), Cap),
            case LessThanCapSize of
                true -> 
                    NewPortInventory = PortInventory#{Port => PortInventoryList ++ ShipInventoryList},
                    NewShipInventory = ShipInventory#{Ship_ID => []},     
                    {shipping_state, Ships, Containers, Ports, ShipLocations, _, _} = Shipping_State,
                {shipping_state, Ships, Containers, Ports, ShipLocations, {ok, NewShipInventory, NewPortInventory}};
            _ -> error
            end;
        _ -> error		
    end.

unload_ship(Shipping_State, Ship_ID, Container_IDs) ->
    ShipLocation = get_ship_location(Shipping_State, Ship_ID),
    case  ShipLocation of
        {Port, _} ->  
            {_, _, _, _, _, ShipInventory, PortInventory} = Shipping_State,
            {_, ShipInventoryList} = maps:find(Ship_ID, ShipInventory),
            {_, PortInventoryList} = maps:find(Port, PortInventory),
            SubListOrNot = lists:all(fun (X) -> lists:member(X, ShipInventoryList) end, Container_IDs),
            case SubListOrNot of
                true -> 
                {_, _, _, _, Container_Cap} = get_port(Shipping_State, Port),
                LessThanCapSize = total_length_greater_than_cap(length(PortInventoryList), length(Container_IDs), Container_Cap),
                case LessThanCapSize of
                    true -> 
                        {shipping_state, Ships, Containers, Ports, Ship_locations, _, _} = Shipping_State,
                        NewShipInventory = ShipInventory#{Ship_ID => lists:subtract(ShipInventoryList, Container_IDs)},
                        NewPortInventory = PortInventory#{Port => PortInventoryList ++ Container_IDs},
                        {ok, {shipping_state, Ships, Containers, Ports,
                        Ship_locations, NewShipInventory, NewPortInventory}};
                    _ -> error
                end;
            _ -> io:format("The given conatiners are not all on the same ship...\n"), error
            end;
        _ -> error          
    end.


set_sail(Shipping_State, Ship_ID, {Port_ID, Dock}) ->
    %%Set sail - Office Hours Notes
    %  1.) get_ship_location -> (port, dock)
    %  2.) get_occ_docs -> Dock
    %     case t -> err
    %         t-> #shipping_state
    %         ports = maps:put(PID, (lists:filter !number(p,PID)))
    case get_ship(Shipping_State, Ship_ID) of 
    error -> error;
    _ ->
        case  is_sublist(get_occupied_docks(Shipping_State, Port_ID), [Dock]) of
        false ->
            {OriginalPort, OriginalDock} = get_ship_location(Shipping_State, Ship_ID),
            ShipLocationList = Shipping_State#shipping_state.ship_locations,
            OldPorts = ShipLocationList -- [{OriginalPort, OriginalDock, Ship_ID}],
            Shipping_State#shipping_state{ship_locations = OldPorts ++ {Port_ID, Dock, Ship_ID}};
        _ -> error
        end 
    end.


%% Determines whether all of the elements of Sub_List are also elements of Target_List
%% @returns true is all elements of Sub_List are members of Target_List; false otherwise
is_sublist(Target_List, Sub_List) ->
    lists:all(fun (Elem) -> lists:member(Elem, Target_List) end, Sub_List).




%% Prints out the current shipping state in a more friendly format
print_state(Shipping_State) ->
    io:format("--Ships--~n"),
    _ = print_ships(Shipping_State#shipping_state.ships, Shipping_State#shipping_state.ship_locations, Shipping_State#shipping_state.ship_inventory, Shipping_State#shipping_state.ports),
    io:format("--Ports--~n"),
    _ = print_ports(Shipping_State#shipping_state.ports, Shipping_State#shipping_state.port_inventory).


%% helper function for print_ships
get_port_helper([], _Port_ID) -> error;
get_port_helper([ Port = #port{id = Port_ID} | _ ], Port_ID) -> Port;
get_port_helper( [_ | Other_Ports ], Port_ID) -> get_port_helper(Other_Ports, Port_ID).


print_ships(Ships, Locations, Inventory, Ports) ->
    case Ships of
        [] ->
            ok;
        [Ship | Other_Ships] ->
            {Port_ID, Dock_ID, _} = lists:keyfind(Ship#ship.id, 3, Locations),
            Port = get_port_helper(Ports, Port_ID),
            {ok, Ship_Inventory} = maps:find(Ship#ship.id, Inventory),
            io:format("Name: ~s(#~w)    Location: Port ~s, Dock ~s    Inventory: ~w~n", [Ship#ship.name, Ship#ship.id, Port#port.name, Dock_ID, Ship_Inventory]),
            print_ships(Other_Ships, Locations, Inventory, Ports)
    end.

print_containers(Containers) ->
    io:format("~w~n", [Containers]).

print_ports(Ports, Inventory) ->
    case Ports of
        [] ->
            ok;
        [Port | Other_Ports] ->
            {ok, Port_Inventory} = maps:find(Port#port.id, Inventory),
            io:format("Name: ~s(#~w)    Docks: ~w    Inventory: ~w~n", [Port#port.name, Port#port.id, Port#port.docks, Port_Inventory]),
            print_ports(Other_Ports, Inventory)
    end.
%% This functions sets up an initial state for this shipping simulation. You can add, remove, or modidfy any of this content. This is provided to you to save some time.
%% @returns {ok, shipping_state} where shipping_state is a shipping_state record with all the initial content.
shipco() ->
    Ships = [#ship{id=1,name="Santa Maria",container_cap=20},
              #ship{id=2,name="Nina",container_cap=20},
              #ship{id=3,name="Pinta",container_cap=20},
              #ship{id=4,name="SS Minnow",container_cap=20},
              #ship{id=5,name="Sir Leaks-A-Lot",container_cap=20}
             ],
    Containers = [
                  #container{id=1,weight=200},
                  #container{id=2,weight=215},
                  #container{id=3,weight=131},
                  #container{id=4,weight=62},
                  #container{id=5,weight=112},
                  #container{id=6,weight=217},
                  #container{id=7,weight=61},
                  #container{id=8,weight=99},
                  #container{id=9,weight=82},
                  #container{id=10,weight=185},
                  #container{id=11,weight=282},
                  #container{id=12,weight=312},
                  #container{id=13,weight=283},
                  #container{id=14,weight=331},
                  #container{id=15,weight=136},
                  #container{id=16,weight=200},
                  #container{id=17,weight=215},
                  #container{id=18,weight=131},
                  #container{id=19,weight=62},
                  #container{id=20,weight=112},
                  #container{id=21,weight=217},
                  #container{id=22,weight=61},
                  #container{id=23,weight=99},
                  #container{id=24,weight=82},
                  #container{id=25,weight=185},
                  #container{id=26,weight=282},
                  #container{id=27,weight=312},
                  #container{id=28,weight=283},
                  #container{id=29,weight=331},
                  #container{id=30,weight=136}
                 ],
    Ports = [
             #port{
                id=1,
                name="New York",
                docks=['A','B','C','D'],
                container_cap=200
               },
             #port{
                id=2,
                name="San Francisco",
                docks=['A','B','C','D'],
                container_cap=200
               },
             #port{
                id=3,
                name="Miami",
                docks=['A','B','C','D'],
                container_cap=200
               }
            ],
    %% {port, dock, ship}
    Locations = [
                 {1,'B',1},
                 {1, 'A', 3},
                 {3, 'C', 2},
                 {2, 'D', 4},
                 {2, 'B', 5}
                ],
    Ship_Inventory = #{
      1=>[14,15,9,2,6],
      2=>[1,3,4,13],
      3=>[],
      4=>[2,8,11,7],
      5=>[5,10,12]},
    Port_Inventory = #{
      1=>[16,17,18,19,20],
      2=>[21,22,23,24,25],
      3=>[26,27,28,29,30]
     },
    #shipping_state{ships = Ships, containers = Containers, ports = Ports, ship_locations = Locations, ship_inventory = Ship_Inventory, port_inventory = Port_Inventory}.
