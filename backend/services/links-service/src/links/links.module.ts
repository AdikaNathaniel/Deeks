import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AuthModule } from '../auth/auth.module';
import { Link, LinkSchema } from './link.schema';
import { LinksController } from './links.controller';
import { LinksService } from './links.service';

@Module({
  imports: [
    MongooseModule.forFeature([{ name: Link.name, schema: LinkSchema }]),
    AuthModule,
  ],
  controllers: [LinksController],
  providers: [LinksService],
})
export class LinksModule {}
