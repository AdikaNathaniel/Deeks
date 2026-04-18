import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuthModule } from '../auth/auth.module';
import { Password, PasswordSchema } from './password.schema';
import { PasswordsController } from './passwords.controller';
import { PasswordsService } from './passwords.service';

@Module({
  imports: [
    MongooseModule.forFeature([
      { name: Password.name, schema: PasswordSchema },
    ]),
    AuthModule,
  ],
  controllers: [PasswordsController],
  providers: [PasswordsService],
})
export class PasswordsModule {}
