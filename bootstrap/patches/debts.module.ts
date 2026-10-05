import { Module } from '@nestjs/common';
import { AuthCoreModule } from '../common/auth/auth-core.module.js';
import { DebtsController } from './debts.controller.js';
import { DebtsService } from './debts.service.js';

@Module({
  imports: [AuthCoreModule],
  controllers: [DebtsController],
  providers: [DebtsService],
})
export class DebtsModule {}
