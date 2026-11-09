/*
This  file is a pseudocode of the call stack where crash has occured
For a perspective, this is how call stack looks at the moment of crash:

Game timer callback                 [CTimerWar3]
 → JASS script execution           [Jass2ScriptInstance_t]
   → CreateUnit(player, 'n004', x, y, facing)  // this is Corrupted from gz btw
	 → engine unit creation/setup  [CUnit]
	   → UI handling               [CGameUI]
		 → Cancel-command lookup
		   → CCommandBar button search
			 → null command-data dereference
*/

UnitHandle CreateUnit(PlayerHandle owner, int unitType,
					 float x, float y, float facing)
{
   Player* player = ResolvePlayer(owner);
   if (!player)
	   return nullptr;

   Unit* unit = AllocateUnit(unitType);

   // Native creation code calls the unit's initialization method.
   unit->Initialize(player, unitType, x, y, facing);

   // Other setup omitted.
   return MakeUnitHandle(unit);
}

void Unit::Initialize(/* ... */)
{
   // Model, stats, position, abilities, etc. omitted.

   // This block is present inside unit initialization.
   const char* tip     = ReadCommandString("CmdCancel", "Tip");
   const char* ubertip = ReadCommandString("CmdCancel", "Ubertip");
   const char* icon    = ReadCommandIcon("CmdCancel");
   auto buttonPosition = ReadCommandPosition("CmdCancel", "Buttonpos");

   constexpr unsigned CancelOrder = 0xD000B;

   UpdateGlobalCommandIcon(
	   0, CancelOrder, buttonPosition, icon /* other flags omitted */
   );

   UpdateGlobalCommandTooltip(
	   0, CancelOrder, tip, nullptr, ubertip, 0, 0, 0
   );
}

void UpdateGlobalCommandTooltip(
   unsigned kind, unsigned order,
   const char* title,
   const char* subtitle,
   const char* description,
   int a, int b, int c)
{
   GameUI* ui = GetGameUI();

   if (!ui || ui->state == 1)
	   return;

   ui->UpdateCommandTooltip(
	   kind, order, title, subtitle, description, a, b, c
   );
}

void GameUI::UpdateCommandTooltip(/* arguments above */)
{
   CommandButton* button =
	   commandBar->FindVisibleButton(kind, order); // CRASH inside here

   if (button) {
	   button->UpdateTooltip(title, subtitle, description, a, b, c);
   } else {
	   // A hash-table lookup, NOT a work queue.
	   CommandData* data = commandBar->FindCachedCommand(kind, order);

	   if (data)
		   data->UpdateTooltip(title, subtitle, description, a, b, c);
   }
}


CommandButton* CommandBar::FindVisibleButton(
   unsigned kind, unsigned order)
{
   for (unsigned column = 0; column < 4; ++column) {
	   for (unsigned row = 0; row < 3; ++row) {
		   CommandButton* button = rows[row].buttons[column];

		   if (!button || !button->IsVisible())
			   continue;

		   CommandData* data = button->commandData; // button + 0x2E8

		   // Missing: if (!data) continue;

		   if (data->keyAt08 == kind &&             // CRASH HERE
			   data->keyAt10 == order)
			   return button;
	   }
   }

   return nullptr;
}